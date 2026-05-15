require 'test_helper'

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'should get index' do
    get settings_url
    assert_response :success
  end

  test 'settings index links map defaults separately from application group defaults' do
    get settings_url

    assert_response :success
    assert_select 'a[href=?]', default_settings_path, text: /Application group defaults/
    assert_select 'a[href=?]', map_default_settings_path, text: /Map defaults/
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
