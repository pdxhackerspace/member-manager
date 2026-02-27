require 'test_helper'

class ProfileSetupInterestsTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    # Sign in as the member_with_local_account fixture user via their local account
    sign_in_as_member
    @current_user = User.find_by(email: local_accounts(:regular_member).email)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  # GET /profile/setup/interests

  test 'shows the interests step' do
    get profile_setup_interests_path
    assert_response :success
    assert_match /Interests/i, response.body
  end

  test 'shows suggested interests' do
    get profile_setup_interests_path
    assert_response :success
    # At least one fixture interest should appear
    assert_match interests(:electronics).name, response.body
  end

  test 'shows completely optional notice' do
    get profile_setup_interests_path
    assert_match /completely optional/i, response.body
  end

  test 'shows skip and continue buttons' do
    get profile_setup_interests_path
    assert_match /Skip/i, response.body
    assert_match /Continue/i, response.body
  end

  test 'skip and continue links go to visibility step' do
    get profile_setup_interests_path
    assert_select "a[href='#{profile_setup_visibility_path}']"
  end

  test 'requires authentication' do
    # Sign out by clearing session
    delete logout_path rescue nil
    get profile_setup_interests_path
    assert_redirected_to login_path
  end

  # POST /profile/setup/interests/:id/add

  test 'adds an interest to the current user' do
    interest = interests(:laser_cutting)
    assert_not @current_user.interests.include?(interest)

    assert_difference -> { @current_user.reload.interests.count }, 1 do
      post profile_setup_add_interest_path(interest)
    end

    assert_redirected_to profile_setup_interests_path
    assert @current_user.reload.interests.include?(interest)
  end

  test 'does not add the same interest twice' do
    # Give the user electronics first
    @current_user.interests << interests(:electronics) unless @current_user.interests.include?(interests(:electronics))

    assert_no_difference -> { @current_user.reload.interests.count } do
      post profile_setup_add_interest_path(interests(:electronics))
    end

    assert_redirected_to profile_setup_interests_path
  end

  test 'redirects gracefully for a non-existent interest id on add' do
    post profile_setup_add_interest_path(id: 999_999)
    assert_redirected_to profile_setup_interests_path
  end

  # DELETE /profile/setup/interests/:id/remove

  test 'removes an interest from the current user' do
    interest = interests(:electronics)
    @current_user.interests << interest unless @current_user.interests.include?(interest)

    assert_difference -> { @current_user.reload.interests.count }, -1 do
      delete profile_setup_remove_interest_path(interest)
    end

    assert_redirected_to profile_setup_interests_path
    assert_not @current_user.reload.interests.include?(interest)
  end

  test 'redirects gracefully for a non-existent interest id on remove' do
    delete profile_setup_remove_interest_path(id: 999_999)
    assert_redirected_to profile_setup_interests_path
  end

  private

  def sign_in_as_member
    post local_login_path, params: {
      session: { email: local_accounts(:regular_member).email, password: 'memberpassword123' }
    }
  end
end
