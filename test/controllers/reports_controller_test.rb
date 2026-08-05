require 'test_helper'

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'index lists every report' do
    get reports_url

    assert_response :success
    Reports::Catalog.reports.each do |report|
      assert_match report.title, response.body, "#{report.key} missing from the report index"
    end
  end

  test 'every report in the catalog renders' do
    Reports::Catalog.reports.each do |report|
      get report_url(report.key)
      assert_response :success, "#{report.key} did not render"
    end
  end

  test 'a report with rows renders its table and inline actions' do
    get report_url('membership-status-unknown')

    assert_response :success
    assert_match users(:one).display_name, response.body
    # The action buttons post back to the report they were used from.
    assert_match 'name="anchor" id="anchor" value="membership-status-unknown"', response.body
  end

  test 'charts render' do
    get reports_charts_url
    assert_response :success
  end

  test 'an unknown report key redirects instead of raising' do
    get report_url('not-a-report')

    assert_redirected_to reports_path
    assert_equal 'Unknown report.', flash[:alert]
  end

  test 'the pre-reorganization view-all urls redirect to the report' do
    get '/reports/dues-status-lapsed/all'
    assert_redirected_to '/reports/dues-status-lapsed'
  end

  test 'active members with no slack lists only active members lacking a linked slack account' do
    linked = users(:one)
    slack_users(:with_dept).update!(user: linked)

    unlinked = users(:two)

    inactive = User.create!(authentik_id: 'authentik-no-slack-inactive', full_name: 'Inactive No Slack',
                            membership_status: 'unknown', dues_status: 'unknown')
    service = User.create!(authentik_id: 'authentik-no-slack-service', full_name: 'Service No Slack',
                           service_account: true, active: true)

    assert_not inactive.reload.active?
    assert service.reload.active?

    get report_url('active-no-slack')

    assert_response :success
    assert_match unlinked.display_name, response.body
    assert_no_match(/#{Regexp.escape(linked.display_name)}/, response.body)
    assert_no_match(/#{Regexp.escape(inactive.display_name)}/, response.body)
    assert_no_match(/#{Regexp.escape(service.display_name)}/, response.body)
  end

  test 'lapsed members with access counts only badge-ins after the last payment' do
    user = lapsed_member('authentik-lapsed-access', Date.new(2025, 1, 15))

    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 1, 10, 9, 0), name: 'before')
    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 2, 1, 9, 0), name: 'after')
    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 3, 1, 9, 0), name: 'later')

    entries = Reports::LapsedWithAccessQuery.new.entries

    assert_equal 2, entries.dig(user.id, :access_count)
    assert_equal Date.new(2025, 1, 15), entries.dig(user.id, :last_payment_date)
    assert_equal Time.zone.local(2025, 3, 1, 9, 0), entries.dig(user.id, :most_recent_at)
  end

  test 'a payment recorded outside the users table still moves the cutoff' do
    user = lapsed_member('authentik-lapsed-paypal', Date.new(2025, 1, 15))
    PaypalPayment.create!(paypal_id: 'txn-lapsed-cutoff', user: user, amount: 40,
                          transaction_time: Time.zone.local(2025, 2, 10, 12, 0))

    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 2, 1, 9, 0), name: 'before paypal')
    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 3, 1, 9, 0), name: 'after paypal')

    entries = Reports::LapsedWithAccessQuery.new.entries

    assert_equal 1, entries.dig(user.id, :access_count)
    assert_equal Date.new(2025, 2, 10), entries.dig(user.id, :last_payment_date)
  end

  test 'lapsed members with no badge-in since their last payment are excluded' do
    user = lapsed_member('authentik-lapsed-quiet', Date.new(2025, 6, 1))
    AccessLog.create!(user: user, logged_at: Time.zone.local(2025, 5, 1, 9, 0), name: 'before only')

    assert_not_includes Reports::LapsedWithAccessQuery.new.entries.keys, user.id
  end

  test 'report counts match the number of rows each report returns' do
    counts = Reports::Catalog.counts

    Reports::Catalog.reports.each do |report|
      assert_equal report.query.relation.count, counts[report.key], "#{report.key} count disagrees with its rows"
    end
  end

  test 'update_user returns to the report it was invoked from' do
    user = users(:one)

    post reports_update_user_path, params: {
      user_id: user.id, action_type: 'paying', anchor: 'dues-status-lapsed'
    }

    assert_redirected_to report_path('dues-status-lapsed')
    assert_equal 'paying', user.reload.membership_status
  end

  private

  # A member with lapsed dues and no payment history beyond the date given, so the
  # cutoff under test is not moved by fixture payments.
  def lapsed_member(authentik_id, last_payment_on)
    User.create!(authentik_id: authentik_id, full_name: "Lapsed #{authentik_id}",
                 membership_status: 'paying', dues_status: 'lapsed', last_payment_date: last_payment_on)
  end

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
