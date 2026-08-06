require 'test_helper'

class NagSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
    NagSetting.seed_defaults!
    MembershipSetting.instance.update!(
      slack_signup_nag_initial_delay_days: 7,
      slack_signup_nag_repeat_delay_days: 14
    )
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'index lists slack signup nag with preview counts' do
    get nag_settings_url

    assert_response :success
    assert_match 'Slack signup reminder', response.body
    assert_match 'would be emailed today', response.body
  end

  test 'show lists due members' do
    now = Time.zone.local(2026, 8, 5, 7, 0, 0)
    user = User.create!(
      email: 'due-preview@example.com',
      full_name: 'Due Preview User',
      active: true,
      service_account: false,
      membership_status: 'paying',
      dues_status: 'current',
      payment_type: 'unknown'
    )
    MembershipApplication.create!(
      user: user,
      email: user.email,
      status: 'approved',
      reviewed_at: now - 10.days,
      submitted_at: now - 12.days
    )

    travel_to now do
      get nag_setting_url('slack_signup')
    end

    assert_response :success
    assert_match 'Due Preview User', response.body
  end

  test 'update toggles nag enabled state' do
    nag = NagSetting.find_by!(key: 'slack_signup')
    nag.update!(enabled: false)

    patch nag_setting_url('slack_signup'), params: { nag_setting: { enabled: '1' } }

    assert_redirected_to nag_settings_url
    assert nag.reload.enabled?
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
