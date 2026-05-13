require 'test_helper'
require 'active_job/test_helper'

class AuthentikUsersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'sync enqueues job when authentik source is enabled' do
    assert_enqueued_with(job: Authentik::GroupSyncJob) do
      post sync_authentik_users_path
    end
    assert_redirected_to authentik_users_path
  end

  test 'sync redirects with alert when authentik source is disabled' do
    member_sources(:authentik).update!(enabled: false)

    assert_no_enqueued_jobs(only: Authentik::GroupSyncJob) do
      post sync_authentik_users_path
    end
    assert_redirected_to authentik_users_path
    assert_equal 'Authentik source is disabled.', flash[:alert]
  end

  test 'index does not show the email column' do
    AuthentikUser.create!(
      authentik_id: 'authentik-index-privacy',
      username: 'auth-index-privacy',
      email: 'authentik-index-private@example.com',
      full_name: 'Authentik Index Privacy',
      raw_attributes: { email: 'authentik-index-private@example.com' }
    )

    get authentik_users_path

    assert_response :success
    assert_select 'th', text: 'Email', count: 0
    assert_select 'a[href^=?]', 'mailto:', count: 0
  end

  test 'show masks email and raw attributes with reveal control' do
    authentik_user = AuthentikUser.create!(
      authentik_id: 'authentik-detail-privacy',
      username: 'auth-detail-privacy',
      email: 'authentik-detail-private@example.com',
      full_name: 'Authentik Detail Privacy',
      raw_attributes: {
        email: 'authentik-detail-private@example.com',
        groups: ['members']
      }
    )

    get authentik_user_path(authentik_user)

    assert_response :success
    assert_select '[data-controller=?]', 'sensitive-reveal'
    assert_select '[data-action=?]', 'click->sensitive-reveal#toggle', text: /Show contact details/
    assert_select '[data-sensitive-reveal-target=?]', 'blurred', text: /authentik-detail-private@example\.com/
    assert_select 'pre[data-sensitive-reveal-target=?]', 'blurred', text: /groups/
  end

  test 'unlink_user disassociates authentik user and clears matching member authentik id' do
    user = users(:two)
    authentik_user = AuthentikUser.create!(
      authentik_id: user.authentik_id,
      username: 'auth-user',
      email: 'auth@example.com',
      full_name: 'Auth User',
      user: user
    )

    post unlink_user_authentik_user_path(authentik_user)

    assert_redirected_to authentik_user_path(authentik_user)
    assert_nil authentik_user.reload.user_id
    assert_nil user.reload.authentik_id
    assert_not user.authentik_dirty?
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
