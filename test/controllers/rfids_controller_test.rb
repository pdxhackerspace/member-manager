require 'test_helper'

class RfidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'new key fob form defaults rfid field to configured facility code prefix' do
    DefaultSetting.instance.update!(rfid_facility_code: 127)

    get new_rfid_url(rfid: { user_id: users(:one).id })

    assert_response :success
    assert_select 'input[name=?][value=?]', 'rfid[rfid]', '127,'
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
