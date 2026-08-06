# UI and Privilege Visibility

A review of how MemberZone's privilege system connects — and mostly does not connect — to
what the interface shows, plus a phased plan to close the gap.

---

## Context

The privilege system landed in PR #642 (`feature/roles-privileges`). It defined a
104-entry catalog and the conferral wiring: privileges bundle into roles, roles attach to
training topics, holding a topic confers that topic's roles. What it did not do is connect
that model to most of the application.

The system reads as complete in the roles editor and is largely inert in practice.

| | |
|---|---|
| Privileges in `Privilege::CATALOG` | 104 (8 topic-scoped, all `training.*`) |
| Enforced anywhere | ~17 |
| View files calling `can?` | 2 |
| Controllers using `require_privilege!` | 7 of 69 |
| Controllers inheriting `AdminController` | 42 |
| Tests asserting UI visibility | 0 |

### What this costs today

**A privilege holder who is not an admin gets no navigation.**
`app/views/layouts/application.html.erb` has one guard — `current_user_admin?` at line 34
— wrapping the entire admin nav. Someone holding `applications.view` can use
`/membership_applications`, because that controller genuinely checks the privilege, but
nothing links there. They must know the URL.

**Four of the eight seeded roles promise access they cannot deliver.**

| Seeded role | Privileges that do nothing |
|---|---|
| Communications editor | **5 of 5 — confers nothing at all** |
| Front desk | 3 of 4 |
| Billing coordinator | 3 of 5 |
| Key fob manager | 1 of 3 |
| Application reviewer / approver / Topic curator / Area lead | 0 — these work |

A director grants "Communications editor" to a volunteer; the volunteer sees "You do not
have access to that section"; the director stops trusting the roles system.

**An admin sees every action regardless of privilege**, so the view layer provides no
defence in depth.

---

## The impersonation model

**Every privilege decision resolves against the impersonated user.** Impersonation exists
so an admin can test the UI *and the logic* a role-holder gets. Resolving against the real
account would defeat that: the admin would see their own buttons on someone else's
profile, and every gate would pass.

This is safe because of one invariant:

> **Only an `is_admin?` account may impersonate, and admins already hold every privilege.**

Resolving against the impersonated user can therefore only ever *subtract*. An admin
impersonating a plain member gets fewer privileges, never more. When nobody is being
impersonated, `current_user == true_user` and nothing changes.

The invariant already holds: `ImpersonationsController` guards **both** `create` and
`destroy` with `require_true_admin!`, which checks `true_user&.is_admin?`.

### What must not change

Four things keep the model safe. Each has a test that fails if it regresses.

1. **Impersonation lapses the moment the real account stops being an administrator.**
   `ApplicationController#impersonating?` re-checks `true_user&.is_admin?` on every
   request, not just when impersonation starts.

   This one was found by an existing test rather than by reasoning. `impersonate_without_admin`
   in `test/controllers/impersonation_privileges_test.rb` sets up a session whose real
   account was demoted mid-session — leaving `true_user` a plain member and `current_user`
   a privileged one. Resolving authorization against `current_user` would have made that
   session *gain* the target's privileges. Checking continuously restores the subtraction
   property: a demoted account simply stops impersonating and falls back to itself.

2. **`ImpersonationsController#require_true_admin!` stays on `true_user`.** It is the only
   authorization check in the app that must, because it is the escape hatch — an admin
   impersonating a zero-privilege member has to be able to stop. The "Stop impersonating"
   banner is likewise driven by `impersonating?`, not by privilege.

3. **`members.impersonate` is gone from the catalog.** If it were ever granted, a non-admin
   could impersonate an *admin* — `current_user` would then be an admin, `can?` would
   return true for everything, and subtraction inverts into full escalation. If delegated
   impersonation is ever wanted it needs a containment rule (only impersonate someone whose
   privileges are a subset of yours), mirroring `User#may_confer?` (`user.rb:266-272`).

4. **Admin bypass stays.** `User#can?` returns `true` for any admin — a deliberate recovery
   path so a bad role edit cannot lock every admin out of the roles UI that would fix it.
   Impersonation is what lets an admin see past their own bypass, which is exactly why it
   is the QA tool for this project.

### Authority versus identity

Who *may act* is the impersonated account. Who is *recorded* as having acted is the real
one. So an administrator viewing as a trainer may record training because that trainer may
— and the resulting `Training` names the administrator. The same split applies to journal
`actor_user`, message senders, and the `*_by` strings inside journal payloads.

`Current.actor` returns the real account and `Current.acting_as` the account being viewed
as; `Journal` stamps the latter into `changes_json` on create, so an entry written while
impersonating reads as "the administrator, acting as this member" rather than as the member
editing their own record.

### Audit attribution

`ApplicationController` sets `Current.user = current_user`, so a write performed while
impersonating is journaled with the **member** as `actor_user`, not the admin
(`user.rb:846,872`, `rfid.rb:28`). Impersonation start and end are journaled correctly
against `true_user`, so the session boundaries are recoverable — but an individual edit is
not attributable without cross-referencing.

This is pre-existing, and it gets more consequential once impersonation is the recommended
way to test. Fold a decision into Phase 0: either record `true_user` as the actor and note
the impersonation in `changes_json`, or add an `impersonated_by_id` column to `journals`.
The second is more work and more honest.

---

## Findings that are security, not cosmetics

### 1. `applications.view_pii` is a no-op — applicant PII is exposed *(high)*

`ApplicationHelper#membership_application_contact_pii_visible?` resolves the privilege and
produces a **CSS blur plus a "Show contact details" button that the application renders
for the user** (`app/views/membership_applications/show.html.erb:1-14`,
`app/javascript/controllers/sensitive_reveal_controller.js`). The values are fully present
in the HTML.

Anyone with `applications.view` — which the **Front desk** preset grants — can read
applicant email, mailing address, phone, and referring-member contact by clicking a
button, or by viewing source. The blur is a smudge you are invited to wipe off.

*Fix:* redact server-side in
`app/controllers/concerns/membership_application_privileges.rb` before values reach the
template; render the reveal control only for holders of `applications.view_pii`, for whom
blur remains a reasonable shoulder-surfing control. Switch the helper's subject from
`true_user` to `current_user` so the redaction is testable by impersonation — its current
comment argues the opposite, and that reasoning inverts under this model.
*Test:* raw-body assertions (`assert_no_match(/#{Regexp.escape(app.email)}/, response.body)`),
not `assert_select` — only a body assertion catches a client-side mask.

### 2. `RagController` is unauthenticated *(high)*

`app/controllers/rag_controller.rb` inherits `ApplicationController` with no
`before_action`; routes expose `/rag` and `/rag.json` unconstrained. Two amplifiers:
`Interest.alphabetical` is unscoped so it includes unmoderated `needs_review` member
free-text, and `TrainingTopic.order(:name)` is unscoped so it includes
`offered_to_members: false` internal topics — and topics are the privilege-conferral
vehicle, so the list partially maps the organisation's authorization structure.

*Fix:* inherit `AuthenticatedController`; scope to `Interest.approved` and
`TrainingTopic.offered_for_members`. If a machine ingest genuinely needs it, use a bearer
token from credentials.
*Note:* `test/controllers/rag_controller_test.rb` currently **asserts the vulnerability**
(`test 'responds without authentication'`). That test must be inverted.

### 3. `MembershipPlansController#new` is ungated *(low, latent)*

`new` appears in neither privilege filter. Impact today is a 500 — there is no action or
template — but the day someone adds `new.html.erb` it becomes an ungated plan-creation
form. *Fix:* add `new` to the `plans.manage` filter **and** `except: [:new]` on the route.

### 4. Authorization subject is inconsistent — and the correct subject is now `current_user`

`user_links_controller.rb:43`, `search_controller.rb:6` and
`training_catalog_controller.rb:98,105,114` use `current_user_admin?`;
`users_controller.rb` and `documents_controller.rb` mostly use `true_user_admin?`, with
`documents_controller.rb:58` a lone `current_user`.

Under this model the `current_user` sites are **already right** and the `true_user` sites
are the ones to change — the reverse of what a first reading suggests. What the
`current_user` sites are actually missing is a privilege check: `search.admin` and
`training.catalog.view_all` exist in the catalog for exactly those decisions and are
enforced nowhere.

The rule to apply everywhere: **authorization resolves against `current_user`; the only
exception in the codebase is `ImpersonationsController`.**

`DocumentsController#download` does have an authorization check (an inline check at lines
56–61, with a deliberately different relationship-based rule from its siblings). Its
`current_user` is correct; the `true_user` calls elsewhere in that file are what should
change.

---

## Decisions taken

- **One subject: the impersonated user.** `can?`, `require_privilege!`, `require_admin!`,
  and the data-scope helpers all resolve against `current_user`. Safe because only admins
  may impersonate, so the substitution can only subtract.
- **Absent, not disabled.** A missing privilege means the affordance is not in the DOM.
- **Hiding is never the only thing preventing an action.** Every hidden affordance still
  needs its controller gate — hiding is a courtesy, not a control.
- **Full audit, phased rollout.** Each phase is independently shippable.

---

## The helper API

Because there is one subject, there is no display/enforcement split to maintain. The
existing `can?` keeps its name and signature; only its subject changes.

```ruby
# app/controllers/application_controller.rb
#
# Authorization resolves against the impersonated account, so an admin impersonating a
# member gets that member's access — which is the point of impersonation. Only an admin
# may impersonate and admins hold everything, so this can only ever subtract.
# ImpersonationsController is the sole exception: it checks true_user, because it is the
# way back out.
def can?(privilege, topic: nil)
  current_user&.can?(privilege, topic: topic) || false
end

def require_admin!
  return if current_user&.is_admin?
  ...
end
```

Two additions for views:

```ruby
# Expose the "any topic" form for nav and index links, where no topic is in hand yet.
# Wraps User#can_for_any_topic? (app/models/user.rb:245), not currently a helper_method.
helper_method :can_for_any_topic?

def can_for_any_topic?(privilege)
  current_user&.can_for_any_topic?(privilege) || false
end
```

```ruby
# app/helpers/privilege_ui_helper.rb
#
# Renders the block only when the privilege is held; nil otherwise, so the affordance is
# absent from the DOM rather than disabled or hidden by CSS. Follows the shape of
# ApplicationHelper#membership_application_masked_contact_capture (line 124).
module PrivilegeUiHelper
  def gate(privilege, topic: nil, any_topic: false, &)
    allowed = any_topic ? can_for_any_topic?(privilege) : can?(privilege, topic: topic)
    return unless allowed

    capture(&)
  end
end
```

Keep both forms. The predicate supports the hoist-to-locals pattern already used at
`training_topics/edit.html.erb:10-15`, which reads better when one key drives several
regions. `gate` suits single items in list context — kebab `<li>`s, table cells, nav items
— where a stray `if/end` silently swallows siblings. More than two uses of one key in a
file → hoist to a local.

`grep -rn 'can?\|can_for_any_topic?\|gate ' app/views` is then the complete inventory of
gated affordances.

---

## Navigation

Replace `layouts/application.html.erb:32-175` with a render of `layouts/_main_nav`, driven
by `app/helpers/main_navigation_helper.rb` — the array-of-hashes shape already used by the
settings index, lifted out of a 200-line layout. Each entry declares the privilege that
reveals it; the nav enforces nothing.

```ruby
{ key: 'members', label: 'Members', items: [
  { key: 'members.index', label: 'Members', path: users_path, privilege: :'members.view_list' },
  :divider,
  { key: 'applications', label: 'Applications', path: membership_applications_path,
    privilege: :'applications.view', controllers: %w[membership_applications] }
] }
```

- **Dropdowns collapse when empty**; one filtered down to a single item renders as a flat
  link — "Payments ▾ → Cash" is a worse affordance than "Cash".
- **Dividers compact** — leading, trailing and doubled rules are dropped after filtering.
- **Active state derives from the tree**, removing the hand-maintained
  `admin_dropdown_active` expression at line 36.
- **Every element emits `data-nav-key`** — this is what makes it testable without Selenium.
- **The member baseline is the absence of privileges, not a branch.** The
  `if current_user_admin? … else … end` split at lines 34/146 disappears; a plain member
  matches zero privileged entries and gets today's Training + Help.
- The brand link (lines 19–27) becomes `can?(:'dashboard.admin')`.

## Settings hub

`app/views/settings/_index_refresh.html.erb` holds 27 items as a literal array rendered
three times. Add `privilege:` and a stable `key:` to each, then one filter line after the
literal:

```erb
<% settings_items = settings_items.select { |item| can?(item[:privilege]) } %>
```

Because the categories, attention items, header count, sidebar counts, all three render
sites and the ⌘K results derive from `settings_items`, that single line fixes every one.
Empty categories vanish on their own. Two follow-ons: gate each attention count in
`SettingsController#index` to its owning privilege so a holder of one row does not trigger
unrelated scans; add a muted zero state and suppress ⌘K below ten rows.

---

## Sequencing — the rule that matters

**Enforcement leads; display follows.** Revealing a nav link whose controller still says
`require_admin!` sends a holder into a redirect — worse than today's invisibility. And
hiding a button whose route stays open is the classic vulnerability, which is what
`applications.view_pii` already is.

Two facts make the ordering safe:

- **Converting an `AdminController` subclass to `require_privilege!` cannot lock anyone
  out.** `User#can?` returns `true` unconditionally for admins, so admins still pass; and
  today the set of non-admins with access is empty, so the change is strictly additive.
  There is no counterexample among the 42.
- **Member-facing controllers are the opposite case.** There, access flows from data
  relationships (`Training`, `TrainerCapability`, being on a plan), not privileges. Gating
  `documents#download` on `training.documents.view_all` would lock every member out of
  their own training materials.

> **On member-facing controllers a privilege is added with `||`, never `&&`.**
> `trainings_controller.rb:128-136` already has the right shape — copy it.

Do not convert `RolesController`, `TrainingTopicRolesController`, or `members.grant_admin`
in the first pass. Those grant authority; they stay admin-only until the
`User#may_confer?` containment rule (`user.rb:266-272`) is proven intact under the new
gates.

Two traps when converting: leaving the class-level `require_admin!` in place makes the new
`require_privilege!` a silent no-op (the parent filter runs first — use `skip_before_action`
or reparent), and views written assuming `current_user_admin?` must be audited in the same
commit or an admin-only partial renders for the new holder.

---

## Phases

| # | Phase | What lands |
|---|---|---|
| 0 | ~~**Hardening**~~ — **done** | Subject switch to `current_user` + impersonation invariant tests; PII redaction; RAG endpoint; plans `new`; journal attribution; route coverage guard test |
| 1 | ~~**Helper + harness**~~ — **done** | `gate`, `can_for_any_topic?` helper_method; lifted the duplicated test sign-in helpers |
| 2 | **Enforce the dead privileges** | The 12 preset keys — additive, zero lockout risk. Includes the `users#show` view-level redesign |
| 3 | **Navigation** | Data-driven nav, `data-nav-key`, collapse and divider rules |
| 4 | **Settings hub** | Filter + `settings.view` gate; convert ~20 destination controllers per category |
| 5 | **Members surface** | Densest page; per-action gates paired with `gate` on every hero button and kebab item |
| 6 | **Remaining areas** | Applications · Payments · Training/documents · Communications · Building/parking · Reports/journal/map/search |
| 7 | **Member-facing, design-first** | Documents, catalog, plans, training requests — privilege added with `\|\|` |
| 8 | **Catalog reconciliation** | Delete or justify no-surface keys; drop `members.impersonate`; add missing keys; coverage test |

Phase 0 must go first: the subject switch is what makes every later phase testable, and it
is a one-line change per call site with a large blast radius, so it wants to land alone
with its invariant tests.

### Phase 2 contains the project's biggest single piece of work

`UsersController#determine_view_level` (lines 683–693) returns one of four ordered levels,
and `users/show.html.erb` branches on `@view_level == :admin` in ~14 places. **A privilege
holder cannot be expressed in that model** — a Front-desk holder with
`members.view_profile` gets `:members`, not a privilege-shaped view. Replace the single
`:admin` bit with a capability set the view consults (`@profile_caps[:membership]`,
`[:notes]`, `[:rfids]`, …), each populated from its privilege, with admin filling all of
them. Keep `@view_level` for the public/members/self ladder — that is visibility, a
different job, and it works.

This must land before anything on the profile page is hidden.

### On the hollow preset roles

**Enforce them; do not remove them.** Removing is the safer code change but the more
dangerous organizational one: the presets are a promise already visible in the roles
editor, and deleting them converts a visible bug into an invisible one. Enforcement here
cannot narrow anyone's access, because every target controller is `AdminController` today.
If Phase 2 cannot land promptly, mark unenforced keys in the roles editor rather than
silently dropping them.

---

## Verification

Integration tests suffice — every affordance is server-rendered ERB, and `assert_select`
answers exactly the question that matters. `test/system/` is empty; adding Selenium here
would be ongoing cost for no extra signal.

Prerequisite: stable selectors — `data-nav-key`, `data-settings-key`, `data-action-key`.
One attribute per element, and text/href assertions stop churning.

### The impersonation invariant tests (Phase 0, non-negotiable)

```ruby
test 'an admin impersonating a plain member loses admin access'
test 'an admin impersonating a plain member can still stop impersonating'
test 'a non-admin cannot start impersonation even with every privilege granted'
test 'no role can confer members.impersonate'   # once the key is removed from the catalog
```

The second is the one that matters most: if `require_true_admin!` ever drifts onto
`current_user`, an admin impersonating a zero-privilege member is trapped in that session.

Impersonation also becomes the cheapest way to write the visibility tests — sign in once
as an admin, impersonate each fixture role-holder, and assert on what renders.

### The affordance assertion

```ruby
# Absent without the privilege, present with it, AND the request refused without it —
# so hiding is never the only protection.
assert_privilege_gates(
  :'members.ban',
  path:     -> { user_path(@member) },
  selector: '[data-action-key="members.ban"]',
  request:  ->(m) { post ban_user_path(m) }
)
```

It signs in as two distinct users rather than granting mid-test: `conferred_privileges` is
memoized per instance (`user.rb:312`), and the session holds a different instance than the
test does.

For nav, assert **exact set equality** of `data-nav-key` values, not inclusion — the
failure mode that matters is an extra item leaking in, which a whitelist of `count: 1`
assertions never catches.

### Coverage guards

Phase 0 adds a **route coverage guard**: walk `Rails.application.routes.routes`, map each
to a controller action, and assert every one is covered by `require_admin!`,
`require_privilege!`, or an explicit public allowlist. That is what stops the
`membership_plans#new` class of defect recurring across 42 controllers. Phase 8 adds a
**catalog coverage test**: every `Privilege::CATALOG` key appears in the nav definition,
the settings array, a `can?`/`gate` call site, or a `NO_DISPLAY_SURFACE` allowlist.

Also lift the `sign_in_as_*` helpers and the `local_auth.enabled` toggle out of the ~40
test files that each define their own, into `test_helper.rb` beside `grant_privileges`.
Add in Phase 1; retrofitting existing files is separate cleanup.

Per phase, before merge: `docker compose -f docker-compose.test.yml run --rm test` and
`docker compose -f docker-compose.lint.yml run --rm rubocop`, both clean.

---

## Open questions for the reviewer

1. **Catalog scope.** Some of the 87 unenforced keys have an obvious home
   (`access.view_logs` → the access log page). Others have no surface at all —
   `applications.create` (no manual-create UI exists), `onboarding.run` and
   `onboarding.approve_mail` (the wizard has no nav or settings entry point),
   `api.users.search` (endpoint-only). Wire up what has a surface and prune the rest, or
   build the missing surfaces?
2. **Surfaces with no privilege** — roles administration itself, the Sidekiq link, login
   branding, the messages inbox, member login-link generation. Add keys, or mark them
   permanently admin-only?
3. **Audit attribution during impersonation.** Record `true_user` as the journal actor, or
   add an `impersonated_by_id` column? The second preserves "the member's record changed"
   while naming who really did it.
4. **Phase 0 urgency.** The PII exposure is live and reachable by anyone holding the Front
   desk role. Split it into its own PR ahead of the subject switch?
