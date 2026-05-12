require 'test_helper'

class RfidReadersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'index shows rfid facility code setting' do
    DefaultSetting.instance.update!(rfid_facility_code: 127)

    get rfid_readers_url

    assert_response :success
    assert_select 'h2', text: 'RFID Facility Code'
    assert_select 'input[name=?][value=?]', 'default_setting[rfid_facility_code]', '127'
    assert_select 'p', text: /default facility code for keyfobs/
  end

  test 'updates rfid facility code setting' do
    patch update_facility_code_rfid_readers_url, params: {
      default_setting: { rfid_facility_code: 127 }
    }

    assert_redirected_to rfid_readers_url
    assert_equal 127, DefaultSetting.instance.reload.rfid_facility_code
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
