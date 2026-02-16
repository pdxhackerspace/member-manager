require 'test_helper'

class UsersIndexFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_local_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  # ─── Basic index ───────────────────────────────────────────────────

  test 'index loads successfully' do
    get users_path
    assert_response :success
  end

  # ─── Payment Plan filtering ────────────────────────────────────────

  test 'index shows payment plan badges' do
    plan = MembershipPlan.create!(name: 'Test Monthly Plan', cost: 50, billing_frequency: 'monthly', plan_type: 'primary')
    users(:one).update_columns(membership_plan_id: plan.id)

    get users_path
    assert_response :success
    assert_match 'Payment Plan', response.body
    assert_match 'Test Monthly Plan', response.body
  end

  test 'filtering by membership_plan_id returns members on that plan' do
    plan = MembershipPlan.create!(name: 'Filter Plan', cost: 75, billing_frequency: 'monthly', plan_type: 'primary')
    users(:one).update_columns(membership_plan_id: plan.id)

    get users_path(membership_plan_id: plan.id)
    assert_response :success
    assert_match users(:one).display_name, response.body
  end

  test 'filtering by membership_plan_id=none returns members without a plan' do
    # Ensure user :one has no plan
    users(:one).update_columns(membership_plan_id: nil)

    get users_path(membership_plan_id: 'none')
    assert_response :success
    assert_match users(:one).display_name, response.body
  end

  test 'filter info bar shows plan name when filtering' do
    plan = MembershipPlan.create!(name: 'Info Bar Plan', cost: 30, billing_frequency: 'monthly', plan_type: 'primary')
    users(:one).update_columns(membership_plan_id: plan.id)

    get users_path(membership_plan_id: plan.id)
    assert_response :success
    assert_match 'Info Bar Plan', response.body
  end

  test 'filter info bar shows No Plan when filtering by none' do
    get users_path(membership_plan_id: 'none')
    assert_response :success
    assert_match 'No Plan', response.body
  end

  # ─── Service account filtering ─────────────────────────────────────

  test 'filtering by account_type=service shows only service accounts' do
    sa = User.create!(
      authentik_id: "sa-filter-#{SecureRandom.hex(4)}",
      full_name: 'Service Filter Test',
      payment_type: 'unknown',
      service_account: true,
      active: true
    )

    get users_path(account_type: 'service')
    assert_response :success
    assert_match 'Service Filter Test', response.body
  end

  test 'filtering by account_type=member excludes service accounts' do
    sa = User.create!(
      authentik_id: "sa-exclude-#{SecureRandom.hex(4)}",
      full_name: 'Service Exclude Test',
      payment_type: 'unknown',
      service_account: true,
      active: true
    )

    get users_path(account_type: 'member')
    assert_response :success
    assert_no_match(/Service Exclude Test/, response.body)
  end

  # ─── Membership status filtering ───────────────────────────────────

  test 'filtering by membership_status works' do
    users(:one).update_columns(membership_status: 'sponsored')

    get users_path(membership_status: 'sponsored')
    assert_response :success
    assert_match users(:one).display_name, response.body
  end

  # ─── Payment type filtering ────────────────────────────────────────

  test 'filtering by payment_type works' do
    users(:one).update_columns(payment_type: 'paypal')

    get users_path(payment_type: 'paypal')
    assert_response :success
    assert_match users(:one).display_name, response.body
  end

  # ─── Dues status filtering ─────────────────────────────────────────

  test 'filtering by dues_status works' do
    users(:one).update_columns(dues_status: 'current')

    get users_path(dues_status: 'current')
    assert_response :success
    assert_match users(:one).display_name, response.body
  end

  # ─── Combined filters ─────────────────────────────────────────────

  test 'clear filters link is shown when filter active' do
    get users_path(payment_type: 'paypal')
    assert_response :success
    assert_match 'Clear filters', response.body
  end

  private

  def sign_in_as_local_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
