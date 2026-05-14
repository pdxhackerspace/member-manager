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

  test 'should show mapped members on map report' do
    users(:one).update!(
      mailing_latitude: 45.582,
      mailing_longitude: -122.682,
      mailing_geocoded_at: Time.current
    )

    get reports_url(tab: 'map')

    assert_response :success
    assert_select '#member-map[data-markers]'
    assert_includes response.body, 'Example User One'
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
