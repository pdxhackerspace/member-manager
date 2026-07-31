require 'test_helper'

class DefaultSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'should get show' do
    get default_settings_url
    assert_response :success
  end

  test 'should get edit' do
    get edit_default_settings_url
    assert_response :success
  end

  test 'should get map defaults' do
    get map_default_settings_url

    assert_response :success
    assert_select 'h1', /Map Defaults/
    assert_match(/Portland/, response.body)
    assert_match(/Oregon/, response.body)
  end

  test 'should get edit map defaults' do
    get edit_map_default_settings_url

    assert_response :success
    assert_select 'h1', /Edit Map Defaults/
  end

  test 'should get branding settings' do
    get branding_default_settings_url

    assert_response :success
    assert_select 'h1', /Login Branding/
  end

  test 'should get edit branding settings' do
    get edit_branding_default_settings_url

    assert_response :success
    assert_select 'h1', /Edit Login Branding/
  end

  test 'should update default settings' do
    patch default_settings_url, params: {
      default_setting: { site_prefix: 'test-prefix' }
    }
    assert_redirected_to default_settings_url
  end

  test 'should update map defaults' do
    patch update_map_default_settings_url, params: {
      default_setting: {
        map_center_latitude: '45.500000',
        map_center_longitude: '-122.600000',
        map_radius_miles: '6.5',
        map_default_city: 'Beaverton',
        map_default_state: 'Oregon'
      }
    }

    assert_redirected_to map_default_settings_url
    setting = DefaultSetting.instance
    assert_equal 45.5, setting.map_center_latitude.to_f
    assert_equal(-122.6, setting.map_center_longitude.to_f)
    assert_equal 6.5, setting.map_radius_miles.to_f
    assert_equal 'Beaverton', setting.map_default_city
    assert_equal 'Oregon', setting.map_default_state
  end

  test 'should update branding settings' do
    patch update_branding_default_settings_url, params: {
      default_setting: {
        login_branding_image: fixture_file_upload('test/fixtures/files/test_document.txt', 'text/plain'),
        login_background_image: fixture_file_upload('test/fixtures/files/test_document.txt', 'text/plain')
      },
      login_message_fragment: {
        content: '<p>Welcome to the portal</p>'
      }
    }

    assert_redirected_to branding_default_settings_url
    setting = DefaultSetting.instance
    assert setting.login_branding_image.attached?
    assert setting.login_background_image.attached?
    assert_equal '<p>Welcome to the portal</p>', TextFragment.content_for('login_screen_message')
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
