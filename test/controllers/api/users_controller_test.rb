require 'test_helper'

module Api
  # Backs the dashboard member search box, which offers to find a member by name, email or
  # username. Email is encrypted, so it matches only as a whole address via its lookup digest.
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
      Rails.application.config.x.local_auth.enabled = true
      sign_in_as_admin
    end

    teardown do
      Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
    end

    test 'blank query returns nothing' do
      get api_users_search_path, params: { q: '' }

      assert_response :success
      assert_empty response.parsed_body
    end

    test 'finds a member by name' do
      get api_users_search_path, params: { q: users(:one).full_name }

      assert_response :success
      assert_includes result_ids, users(:one).id
    end

    test 'finds a member by their whole email address' do
      users(:one).update!(email: 'picker-target@example.com')

      get api_users_search_path, params: { q: 'picker-target@example.com' }

      assert_response :success
      assert_includes result_ids, users(:one).id
    end

    test 'matches the email case-insensitively and ignores surrounding space' do
      users(:one).update!(email: 'picker-target@example.com')

      get api_users_search_path, params: { q: '  Picker-Target@Example.COM ' }

      assert_response :success
      assert_includes result_ids, users(:one).id
    end

    test 'finds a member by an extra email address' do
      users(:one).update!(extra_emails: ['picker-alternate@example.com'])

      get api_users_search_path, params: { q: 'picker-alternate@example.com' }

      assert_response :success
      assert_includes result_ids, users(:one).id
    end

    private

    def result_ids
      response.parsed_body.pluck('id')
    end

    def sign_in_as_admin
      post local_login_path, params: {
        session: { email: local_accounts(:active_admin).email, password: 'localpassword123' }
      }
    end
  end
end
