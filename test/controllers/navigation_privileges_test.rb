require 'test_helper'

# Navigation is the only way a privilege holder reaches anything. The dashboard is
# administrator-only and `root` points at it, so a holder signing in lands on their own
# profile — an enforced privilege with no navbar entry is unreachable unless they guess the
# URL.
#
# Visibility is asserted as an exact set rather than "includes", because the failure that
# matters here is an extra entry appearing, and a list of `count: 1` assertions never
# notices one.
class NavigationPrivilegesTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'a plain member sees only training' do
    sign_in_as_plain_member

    assert_equal %w[training], nav_keys_on(help_path)
  end

  test 'an administrator still sees every entry' do
    sign_in_as_admin

    keys = nav_keys_on(help_path)

    %w[members_index authentik sheet slack applications incident_reports
       paypal recharge kofi cash payment_events training journal
       access_logs parking reports member_map queued_mail mail_log settings sidekiq].each do |key|
      assert_includes keys, key, "an administrator should still see #{key}"
    end
  end

  test 'members.view_list reveals the Members dropdown and only its own entry' do
    holder('members.view_list')

    assert_equal %w[members_index training].sort, nav_keys_on(help_path)
    assert_collapsed_to_flat_entry 'members', 'members_index'
  end

  test 'applications.view reveals the Members dropdown for the application queue' do
    holder('applications.view')

    assert_equal %w[applications training].sort, nav_keys_on(help_path)
    assert_collapsed_to_flat_entry 'members', 'applications'
  end

  # Settings comes along because its Recharge row — the one carrying the "needs linking"
  # count — is itself gated on payments.view. Cash and the event log do not.
  test 'payments.view reveals the Payments dropdown without cash or events' do
    holder('payments.view')

    assert_equal %w[paypal recharge kofi settings training].sort, nav_keys_on(help_path)
    assert_section_visible 'payments'
  end

  test 'payments.view_events reveals the Payments dropdown for the event log alone' do
    holder('payments.view_events')

    assert_equal %w[payment_events training].sort, nav_keys_on(help_path)
    assert_collapsed_to_flat_entry 'payments', 'payment_events'
  end

  test 'queued_mail.view reveals the Admin dropdown for the mail queue alone' do
    holder('queued_mail.view')

    assert_equal %w[queued_mail training].sort, nav_keys_on(help_path)
    assert_collapsed_to_flat_entry 'admin', 'queued_mail'
  end

  test 'a dropdown with nothing to show does not render' do
    holder('members.view_list')

    get help_path

    assert_select '[data-nav-section="payments"]', count: 0
    assert_select '[data-nav-section="building"]', count: 0
    assert_select '[data-nav-section="admin"]', count: 0
  end

  # A settings row the holder can open is enough to reveal the hub; nobody has to be
  # granted settings.view on top of what they already hold.
  test 'a settings row reveals the Settings entry and the hub itself' do
    holder('text_fragments.manage')

    assert_includes nav_keys_on(help_path), 'settings'
    assert_collapsed_to_flat_entry 'admin', 'settings'

    get settings_path
    assert_response :success
  end

  test 'the settings hub shows only the rows the holder can open' do
    holder('text_fragments.manage')

    get settings_path

    assert_response :success
    assert_select 'a[href=?]', text_fragments_path
    assert_select 'a[href=?]', roles_path, count: 0
    assert_select 'a[href=?]', ai_providers_path, count: 0
  end

  test 'the settings hub is refused when no row is visible' do
    holder('payments.view_events')

    get settings_path

    assert_response :redirect
  end

  # ─── The seeded roles, end to end ─────────────────────────────────────

  test 'Front desk sees the member directory and the application queue' do
    holder(*seeded_privileges('Front desk'))

    assert_equal %w[members_index applications training settings].sort, nav_keys_on(help_path)
  end

  test 'Communications editor sees the mail queue and its settings rows' do
    holder(*seeded_privileges('Communications editor'))

    keys = nav_keys_on(help_path)
    assert_includes keys, 'queued_mail'
    assert_includes keys, 'mail_log'
    assert_includes keys, 'settings'
    assert_not_includes keys, 'members_index'
    assert_not_includes keys, 'paypal'
  end

  test 'Billing coordinator sees payments and nothing from communications' do
    holder(*seeded_privileges('Billing coordinator'))

    keys = nav_keys_on(help_path)
    assert_includes keys, 'paypal'
    assert_not_includes keys, 'queued_mail'
    assert_not_includes keys, 'members_index'
  end

  test 'Key fob manager gets no navigation of its own' do
    holder(*seeded_privileges('Key fob manager'))

    # Key fobs are managed from a member profile, so this role depends on someone else
    # holding members.view_list to reach one. Worth knowing rather than assuming.
    assert_equal %w[training], nav_keys_on(help_path)
  end

  private

  def seeded_privileges(name)
    Role::DEFAULT_ROLES.find { |role| role[:name] == name }.fetch(:privileges)
  end

  def nav_keys_on(path)
    get path
    assert_response :success
    css_select('[data-nav-key]').pluck('data-nav-key').sort
  end

  # A section holding one visible entry collapses to a flat link — a dropdown containing a
  # single item is a worse affordance than the item itself. Either shape is reachable; what
  # must never happen is the entry being present with no way to click it.
  def assert_section_visible(section)
    assert_select %([data-nav-section="#{section}"]), 1,
                  "the #{section} dropdown must render so its entries are reachable"
  end

  def assert_collapsed_to_flat_entry(section, key)
    assert_select %([data-nav-section="#{section}"]), 0,
                  'a section with one visible entry should not render as a dropdown'
    assert_select %(li.nav-item[data-nav-key="#{key}"]), 1,
                  "#{key} should render as a flat nav item once its section collapsed"
  end

  def holder(*privilege_keys)
    member = sign_in_as_plain_member
    privilege_keys.each { |key| grant_privileges(member, key) }
    sign_in_as_plain_member
  end
end
