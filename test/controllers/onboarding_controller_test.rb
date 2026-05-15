require 'test_helper'

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'payment step supports usernames containing dots' do
    user = users(:one)
    user.update!(username: 'joseph.sabio')

    get onboard_payment_path(user)

    assert_response :success
  end

  test 'access step defaults rfid field to configured facility code prefix' do
    DefaultSetting.instance.update!(rfid_facility_code: 127)

    get onboard_access_path(users(:one))

    assert_response :success
    assert_select 'input[name=?][value=?]', 'rfid_code', '127,'
  end

  test 'create member requires an email address' do
    assert_no_difference 'User.count' do
      post onboard_create_path, params: {
        user: {
          full_name: 'Missing Email',
          username: 'missingemail',
          email: ''
        }
      }
    end

    assert_response :unprocessable_content
    assert_select '.alert-danger', text: /Email can't be blank/
  end

  test 'create member validates email format' do
    assert_no_difference 'User.count' do
      post onboard_create_path, params: {
        user: {
          full_name: 'Invalid Email',
          username: 'invalidemail',
          email: 'not-an-email'
        }
      }
    end

    assert_response :unprocessable_content
    assert_select '.alert-danger', text: /Email is invalid/
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
