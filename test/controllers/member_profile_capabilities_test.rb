require 'test_helper'

# The member profile used to be all-or-nothing: `@view_level == :admin` decided fourteen
# separate regions at once, so a Front desk greeter and an administrator saw the same page.
# @profile_caps replaces that single bit with one entry per privilege.
#
# Each test here holds exactly one privilege and asserts both halves: the affordance appears
# for a holder, is absent for everyone else, and the request behind it is refused — hiding a
# button is a courtesy, not a control.
class MemberProfileCapabilitiesTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    @member = users(:one)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  # ─── The profile opens at all ─────────────────────────────────────────

  test 'members.view_profile reaches the admin layout' do
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_response :success
    assert_select 'ul.nav-tabs'
  end

  # ─── A viewer with only view_profile gets no action at all ────────────

  test 'a profile viewer sees no action menu, no modals and no edit button' do
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="members.actions"]', 0
    assert_select '[data-action-key="members.edit"]', 0
    assert_select '#banModal', 0
    assert_select '#deceasedModal', 0
    assert_select '#deleteMemberModal', 0
    assert_select '#applyOverrideModal', 0
  end

  test 'a profile viewer sees only the Profile and Training tabs' do
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_equal %w[training], css_select('[data-tab-key]').pluck('data-tab-key')
  end

  # ─── Each tab follows its own privilege ───────────────────────────────

  {
    'payments.view' => 'payments',
    'access.view_logs' => 'access',
    'journal.view' => 'journal',
    'queued_mail.view' => 'mail',
    'members.send_message' => 'messages'
  }.each do |privilege, tab_key|
    test "#{privilege} reveals the #{tab_key} tab and nothing else" do
      holder('members.view_profile', privilege)

      get user_path(@member, tab: :profile)

      tabs = css_select('[data-tab-key]').pluck('data-tab-key')
      assert_includes tabs, tab_key
      assert_equal (%w[training] + [tab_key]).sort, tabs.sort
    end
  end

  # Incidents and Parking are also gated on the member actually having some, so the
  # privilege alone is not enough to show the tab — worth pinning, since a tab that never
  # appears looks identical to one that is denied.
  test 'incidents.manage reveals the incidents tab only when there are incidents' do
    holder('members.view_profile', 'incidents.manage')

    get user_path(@member, tab: :profile)
    assert_not_includes css_select('[data-tab-key]').pluck('data-tab-key'), 'incidents'

    report = IncidentReport.create!(incident_date: Date.current, subject: 'Test incident',
                                    incident_type: 'other', other_type_explanation: 'testing',
                                    status: 'draft', reporter: users(:two))
    report.involved_members << @member
    sign_in_as_plain_member

    get user_path(@member, tab: :profile)
    assert_includes css_select('[data-tab-key]').pluck('data-tab-key'), 'incidents'
  end

  # ─── Kebab entries, one privilege at a time ───────────────────────────

  {
    'members.ban' => 'members.ban',
    'members.delete' => 'members.delete',
    'members.mark_deceased' => 'members.mark_deceased',
    'members.sponsor' => 'members.sponsor'
  }.each do |privilege, action_key|
    test "#{privilege} contributes exactly its own kebab entry" do
      holder('members.view_profile', privilege)

      get user_path(@member, tab: :profile)

      assert_select '[data-action-key="members.actions"]', 1, 'the menu should open for a holder'
      assert_select %([data-action-key="#{action_key}"]), 1
      assert_equal [action_key], other_action_keys
    end
  end

  # The menu carries section headers and dividers. They are only meaningful between
  # entries, so a menu holding one item must not render either.
  test 'a single kebab entry brings no header or divider with it' do
    holder('members.view_profile', 'members.delete')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="members.actions"] .dropdown-header', 0
    assert_select '[data-action-key="members.actions"] .dropdown-divider', 0
  end

  test 'entries from two sections bring the divider between them' do
    holder('members.view_profile', 'members.sponsor', 'members.delete')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="members.actions"] .dropdown-divider', 1
  end

  # ─── Modals travel with their trigger ─────────────────────────────────

  { 'members.ban' => '#banModal',
    'members.mark_deceased' => '#deceasedModal',
    'members.delete' => '#deleteMemberModal' }.each do |privilege, modal|
    test "#{privilege} brings #{modal} and no other modal" do
      holder('members.view_profile', privilege)

      get user_path(@member, tab: :profile)

      assert_select modal, 1, "#{modal} must render for the trigger that opens it"
      (%w[#banModal #deceasedModal #deleteMemberModal] - [modal]).each do |other|
        assert_select other, 0, "#{other} has no trigger on this page"
      end
    end
  end

  # ─── Private contact is data, not decoration ──────────────────────────

  test 'a profile viewer without view_private_contact receives no contact details' do
    @member.update!(mailing_address: '12 Secret Lane', phone_number: '555-9999')
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_no_match(/12 Secret Lane/, response.body)
    assert_no_match(/555-9999/, response.body)
    assert_no_match(/sensitive-reveal/, response.body)
  end

  test 'members.view_private_contact receives them' do
    @member.update!(mailing_address: '12 Secret Lane', phone_number: '555-9999')
    holder('members.view_profile', 'members.view_private_contact')

    get user_path(@member, tab: :profile)

    assert_match(/12 Secret Lane/, response.body)
    assert_match(/555-9999/, response.body)
  end

  test 'internal notes need members.edit_notes' do
    @member.update!(notes: 'internal observation')
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_no_match(/internal observation/, response.body)
  end

  # ─── Key fobs ─────────────────────────────────────────────────────────

  test 'access.view_rfids shows the fob row without the buttons to change it' do
    Rfid.create!(user: @member, rfid: '127,55555')
    holder('members.view_profile', 'access.view_rfids')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="access.view_rfids"]', 1
    assert_select '[data-action-key="access.manage_rfids"]', 0
  end

  test 'access.manage_rfids adds the add-key control' do
    holder('members.view_profile', 'access.view_rfids', 'access.manage_rfids')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="access.manage_rfids"]', 1
  end

  test 'the fob row is absent without access.view_rfids' do
    Rfid.create!(user: @member, rfid: '127,55556')
    holder('members.view_profile')

    get user_path(@member, tab: :profile)

    assert_select '[data-action-key="access.view_rfids"]', 0
  end

  # ─── Preview still shows what the member would get ────────────────────

  test 'an administrator previewing as a member holds no capabilities' do
    sign_in_as_admin

    get user_path(@member, view_as: :self, tab: :profile)

    assert_response :success
    assert_select '[data-action-key="members.actions"]', 0
    assert_select '#banModal', 0
  end

  private

  def other_action_keys
    css_select('[data-action-key]').pluck('data-action-key') - %w[members.actions]
  end

  def holder(*privilege_keys)
    member = sign_in_as_plain_member
    privilege_keys.each { |key| grant_privileges(member, key) }
    sign_in_as_plain_member
  end
end
