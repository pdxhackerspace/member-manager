# Member Zone rename — deploy notes

Reference for the Member Manager → Member Zone rename. Delete once every environment is
past it.

## Blocking — do before deploying

- **Set `DATABASE_FIELD_ENCRYPTION_KEY` and `EMAIL_LOOKUP_HMAC_KEY` explicitly in every
  environment.** The `SensitiveData` key-derivation salts changed from `member-manager-*`
  to `member-zone-*`. The salts only apply when a variable is unset and the key is derived
  from `secret_key_base` — an environment on that fallback gets different keys after the
  deploy and cannot decrypt its own data or match any email lookup digest. Neither variable
  was previously in any `.env` example, so assume the fallback is in use until verified.
  See [encrypted-fields.md](encrypted-fields.md).
- **Rename the OIDC scope in Authentik to `member_zone_admin`.** `config/initializers/omniauth.rb`
  requests the new name. Admin login breaks until Authentik matches.
- **Point deploy targets at the renamed image**, `ghcr.io/<owner>/member-zone`. The old path
  stops receiving builds.
- **Run migrations.** Both are data-only and reversible.
  - `20260806000000_rename_member_manager_source_key_to_member_zone` moves
    `member_sources.key` from `member_manager` to `member_zone`.
  - `20260806000100_rename_member_manager_system_application` renames the `applications`
    row that owns every core and training group. `Authentik::CoreGroupProvisioner` finds it
    by name and `applications.name` has no unique index, so without this the next
    provisioning run builds a second application, rebuilds every group under it, and leaves
    the originals orphaned with two records pushing to the same Authentik group.
    `CoreGroupProvisioner.system_application` also adopts the old row at runtime, which
    covers restoring a pre-rename dump into a migrated schema.
  - If an instance already holds both a `Member Manager` and a `Member Zone` application,
    the migration leaves the data alone. Merge them by hand.

## Non-blocking — do soon

- **Move deployments off `MEMBER_MANAGER_BASE_URL` to `MEMBER_ZONE_BASE_URL`**, then drop
  the fallback in `config/initializers/member_zone.rb`.
- **Stale Authentik user/group attributes.** The app now writes `member_zone_id`,
  `member_zone_application`, `member_zone_group_id`, `member_zone_synced_at`. Writes merge
  rather than replace, so the `member_manager_*` keys linger. Cosmetic — nothing reads them.
- **Local dev volumes.** Compose project names changed, so named volumes get a new
  `memberzone-*` prefix and local dev/test databases start empty. Old volumes and
  `member_manager_*` images can be pruned.
- **Duplicate Authentik webhook objects from a pre-fix deploy.** If setup already ran once
  against the rename and created `MemberZone *` objects alongside the old `MemberManager *`
  ones, adoption code keeps using the new names and logs a warning. Delete the orphans in
  Authentik by hand.

## Rename lookup sweep (code)

These were the name-keyed lookups that could fork persisted state. All are handled in code
now unless noted.

| Location | Risk | Fix |
| --- | --- | --- |
| `CoreGroupProvisioner.system_application` | Second `applications` row; groups orphaned | Migration + runtime adoption |
| `MemberSource.seed_defaults!` | Second `member_sources` row on `db:seed` | Adopts `member_manager` key |
| `Authentik::WebhookSetup` | Duplicate transport/policies/rule in Authentik | Adopts and renames legacy objects |
| `TrainingTopic#provision_authentik_groups` | Same as system application | Uses `system_application` |
| `MemberSource.for('member_zone')` | N/A — keyed lookup after migration | Migration |
| Email templates, text fragments, incoming webhooks, privileges, roles | Keyed by stable `key`/`webhook_type`, not display name | No change |
| `ORGANIZATION_NAME` default | Display string only | No fork risk |
| OIDC scope `member_zone_admin` | External Authentik config | Manual rename (blocking above) |

## Open — deliberately not renamed

- **Staging and production database names** stay `member_manager_staging` and
  `member_manager_production` (`config/database.yml`, and the `DATABASE_URL` examples in
  `.env.staging.example` / `.env.production.example`). Renaming needs an `ALTER DATABASE`
  plus a coordinated env change. Decide whether to do it or make the old names permanent.
- **The GitHub repository** is still `pdxhackerspace/member-manager`. The workflows build
  the image name from `github.repository_owner`, not the repo name, so a repo rename is
  independent of this work.
- **Action Cable `channel_prefix`** was renamed to `member_zone_*`. Harmless, but in-flight
  connections drop at deploy.

## Backward compatibility kept in code

- `MEMBER_MANAGER_BASE_URL` still read as a fallback — `MemberZoneConfig.base_url`.
- Pre-rename Authentik webhook object names still adopted and renamed on setup —
  `Authentik::WebhookSetup::LEGACY_*_NAME`.
- `member-manager.role-definitions` still accepted on import — `DefinitionExport::LEGACY_FORMAT`.
- `membermanager:anonymized_export v1` still accepted on restore — `DatabaseAnonymizer::LEGACY_DUMP_MARKER`.
- Mail trace headers are now `X-MemberZone-*` with no fallback, which is fine: headers are
  set when the message is rendered at delivery time, so queued mail picks up the new names.

## Not touched

- Git history and changelogs.
- `SensitiveData` ciphertext and digests — no re-encryption pass was run.
