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

  test 'should get index' do
    get reports_url
    assert_response :success
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

    get reports_view_all_url('active-no-slack')

    assert_response :success
    assert_match unlinked.display_name, response.body
    assert_no_match(/#{Regexp.escape(linked.display_name)}/, response.body)
    assert_no_match(/#{Regexp.escape(inactive.display_name)}/, response.body)
    assert_no_match(/#{Regexp.escape(service.display_name)}/, response.body)
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
