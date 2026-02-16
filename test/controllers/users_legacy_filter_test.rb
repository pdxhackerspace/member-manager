require 'test_helper'

class UsersLegacyFilterTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_local_admin

    @legacy_user = User.create!(
      authentik_id: "legacy-filter-#{SecureRandom.hex(4)}",
      full_name: 'Legacy Filter Member',
      payment_type: 'unknown',
      legacy: true
    )
    @regular_user = users(:one)
    @regular_user.update_columns(legacy: false)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'index excludes legacy members by default' do
    get users_path
    assert_response :success
    assert_no_match(/Legacy Filter Member/, response.body)
    assert_match @regular_user.display_name, response.body
  end

  test 'filtering by account_type=legacy shows only legacy members' do
    get users_path(account_type: 'legacy')
    assert_response :success
    assert_match 'Legacy Filter Member', response.body
  end

  test 'legacy badge is shown in account type section' do
    get users_path
    assert_response :success
    assert_match 'Legacy', response.body
  end

  test 'filter info bar shows Legacy Members when filtering' do
    get users_path(account_type: 'legacy')
    assert_response :success
    assert_match 'Legacy Members', response.body
  end

  test 'legacy user shows legacy badge in table row when viewing legacy filter' do
    get users_path(account_type: 'legacy')
    assert_response :success
    assert_match 'bi-archive', response.body
  end

  test 'admin can mark a member as legacy via edit' do
    patch user_path(@regular_user), params: { user: { legacy: '1' } }
    @regular_user.reload
    assert @regular_user.legacy?, 'Member should be marked as legacy'
  end

  test 'admin can un-mark a legacy member via edit' do
    patch user_path(@legacy_user), params: { user: { legacy: '0' } }
    @legacy_user.reload
    assert_not @legacy_user.legacy?, 'Member should be un-marked as legacy'
  end

  private

  def sign_in_as_local_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
