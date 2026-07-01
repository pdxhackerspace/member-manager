require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'admin home defaults to admin dashboard tab' do
    get root_path
    assert_response :success

    assert_match(/Admin Dashboard/i, response.body)
    assert_match(/Member Dashboard/i, response.body)
    assert_match(/Find a member by name, email or username/i, response.body)
    assert_match(/Recent Highlights/i, response.body)
  end

  test 'admin home member dashboard tab renders member dashboard content' do
    get root_path(tab: :member_dashboard)
    assert_response :success

    assert_match(/Quick actions/i, response.body)
    assert_match(/Membership/i, response.body)
    assert_match(/Request training/i, response.body)
  end

  test 'admin home includes normal user tabs' do
    get root_path(tab: :payments)
    assert_response :success
    assert_match(/Payment Events/i, response.body)

    get root_path(tab: :profile)
    assert_response :success

    get root_path(tab: :member_dashboard)
    assert_response :success
    assert_match(/Request training/i, response.body)
  end

  test 'admin home parking tab shows print for permits but not tickets' do
    admin_user = User.find_by!(email: local_accounts(:active_admin).email)
    printer = Printer.create!(name: 'Front Desk', cups_printer_name: 'front_desk')
    permit = admin_user.parking_notices.create!(
      notice_type: 'permit', status: 'active', issued_by: admin_user,
      expires_at: 3.days.from_now, description: 'Home permit', location: 'Woodshop'
    )
    ticket = ParkingNotice.create!(
      notice_type: 'ticket', status: 'active', user: admin_user, issued_by: admin_user,
      expires_at: 3.days.from_now, description: 'Home ticket', location: 'Main Area'
    )

    get root_path(tab: :parking)

    assert_response :success
    assert_select 'a[href=?]', print_notice_member_parking_permit_path(permit, printer_id: printer.id)
    assert_select 'a[href=?]', print_notice_member_parking_permit_path(ticket, printer_id: printer.id), count: 0
  end

  test 'member home payments details use source labels without payer emails' do
    admin_user = User.find_by!(email: local_accounts(:active_admin).email)
    [
      ['paypal', 'PAY-HOME-PRIVACY', 'PayPal payment from private-paypal@example.com'],
      ['recharge', 'RECHARGE-HOME-PRIVACY', 'Recharge payment from private-recharge@example.com'],
      ['kofi', 'KOFI-HOME-PRIVACY', 'Ko-Fi Tip from private-kofi@example.com']
    ].each do |source, external_id, details|
      PaymentEvent.create!(
        user: admin_user,
        source: source,
        external_id: external_id,
        event_type: 'payment',
        details: details,
        amount: 10,
        currency: 'USD',
        occurred_at: Time.current
      )
    end

    get root_path(tab: :payments)

    assert_response :success
    assert_select 'td', text: 'PayPal payment'
    assert_select 'td', text: 'Recharge payment'
    assert_select 'td', text: 'Ko-Fi Tip'
    assert_no_match(/private-paypal@example\.com/, response.body)
    assert_no_match(/private-recharge@example\.com/, response.body)
    assert_no_match(/private-kofi@example\.com/, response.body)
  end

  test 'home messages nav badge only shows unread count' do
    admin_user = User.find_by!(email: local_accounts(:active_admin).email)
    Message.where(recipient: admin_user).destroy_all
    Message.create!(
      sender: users(:one),
      recipient: admin_user,
      subject: 'Read home message',
      body: 'Already read',
      read_at: Time.current
    )

    get root_path(tab: :member_dashboard)

    assert_response :success
    assert_select 'a.nav-link[href=?]', messages_path(folder: :unread) do
      assert_select '.badge', count: 0
    end
  end

  test 'admin dashboard marks stale membership applications urgent' do
    MembershipApplication.create!(
      email: 'stale-dashboard@example.com',
      status: 'submitted',
      submitted_at: 8.days.ago,
      created_at: 8.days.ago
    )

    with_urgent_snapshot(urgent_snapshot) { get root_path }

    assert_response :success
    assert_match(/1 over a week old/, response.body)
    assert_match(/pending membership application/i, response.body)
  end

  test 'admin dashboard shows recent pending applications without stale warning' do
    MembershipApplication.create!(
      email: 'recent-dashboard@example.com',
      status: 'submitted',
      submitted_at: 2.days.ago,
      created_at: 2.days.ago
    )

    with_urgent_snapshot(urgent_snapshot) { get root_path }

    assert_response :success
    assert_match(/pending membership application/i, response.body)
    assert_no_match(/over a week old/, response.body)
  end

  test 'admin dashboard urgent items come from shared urgent snapshot' do
    snapshot = AdminDashboard::UrgentItems::Snapshot.new(
      [],
      0,
      2,
      3,
      4,
      9,
      [],
      nil,
      false,
      nil,
      MailerHealthCheck::Result.new('healthy', 'Connected and authenticated to smtp.example.test:587', Time.current),
      [],
      false,
      [],
      []
    )

    original_snapshot = AdminDashboard::UrgentItems.method(:snapshot)
    AdminDashboard::UrgentItems.define_singleton_method(:snapshot) { |**_kwargs| snapshot }
    begin
      get root_path
    ensure
      AdminDashboard::UrgentItems.define_singleton_method(:snapshot, original_snapshot)
    end

    assert_response :success
    assert_match(%r{9</strong> access controller issues}, response.body)
    assert_match(/2 offline, 3 sync failed, 4 backup failed/, response.body)
  end

  test 'admin dashboard shows mailer health in no action list when healthy' do
    snapshot = urgent_snapshot(
      mailer_health: MailerHealthCheck::Result.new(
        'healthy',
        'Connected and authenticated to smtp.example.test:587',
        Time.current
      )
    )

    with_urgent_snapshot(snapshot) { get root_path }

    assert_response :success
    assert_match(/Outgoing mail is healthy/, response.body)
    assert_match(/Connected and authenticated to smtp.example.test:587/, response.body)
  end

  test 'admin dashboard marks mailer health urgent when unhealthy' do
    snapshot = urgent_snapshot(
      items: [
        AdminDashboard::UrgentItems::Item.new(
          :mailer_health,
          'Outgoing mail is unhealthy',
          'SMTP authentication failed',
          mail_log_path
        )
      ],
      mailer_health: MailerHealthCheck::Result.new('unhealthy', 'SMTP authentication failed', Time.current)
    )

    with_urgent_snapshot(snapshot) { get root_path }

    assert_response :success
    assert_match(/Outgoing mail is unhealthy/, response.body)
    assert_match(/SMTP authentication failed/, response.body)
  end

  private

  def urgent_snapshot(items: [], mailer_health: nil)
    AdminDashboard::UrgentItems::Snapshot.new(
      items,
      0,
      0,
      0,
      0,
      0,
      [],
      nil,
      false,
      nil,
      mailer_health || MailerHealthCheck::Result.new('healthy', 'Connected', Time.current),
      [],
      false,
      [],
      []
    )
  end

  def with_urgent_snapshot(snapshot)
    original_snapshot = AdminDashboard::UrgentItems.method(:snapshot)
    AdminDashboard::UrgentItems.define_singleton_method(:snapshot) { |**_kwargs| snapshot }
    yield
  ensure
    AdminDashboard::UrgentItems.define_singleton_method(:snapshot, original_snapshot)
  end

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: {
        email: account.email,
        password: 'localpassword123'
      }
    }
  end
end
