require 'test_helper'

# Authorization resolves against the account being viewed as. These cover the subject
# itself — that a privilege granted to the impersonated member is the one that counts, and
# that an administrator's own access does not leak through while they are viewing as
# someone else.
class AuthorizationSubjectTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    @topic = training_topics(:laser_cutting)
    @member = users(:one)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'an administrator alone reaches an admin page' do
    sign_in_as_admin

    get users_path

    assert_response :success
  end

  test 'an administrator viewing as a plain member does not' do
    sign_in_as_admin
    post impersonate_user_path(@member.id)

    get users_path

    assert_response :redirect
  end

  test 'a privilege held by the impersonated member is the one that counts' do
    grant_privileges(@member, 'plans.manage')
    sign_in_as_admin
    post impersonate_user_path(@member.id)

    get membership_plans_path

    assert_response :success
  end

  test 'a privilege the impersonated member lacks is refused even to an administrator' do
    sign_in_as_admin
    post impersonate_user_path(@member.id)

    get membership_plans_path

    assert_response :redirect
  end

  test 'authority returns when impersonation ends' do
    sign_in_as_admin
    post impersonate_user_path(@member.id)
    get users_path
    assert_response :redirect

    delete stop_impersonation_path
    get users_path

    assert_response :success
  end

  test 'a plain member is unaffected by the subject change' do
    sign_in_as_plain_member

    get users_path

    assert_response :redirect
  end

  test 'a member holding a privilege reaches the page it guards' do
    member = sign_in_as_plain_member
    grant_privileges(member, 'plans.manage')
    sign_in_as_plain_member

    get membership_plans_path

    assert_response :success
  end

  # Topic-scoped privileges have to carry the topic through the same subject.
  test 'a topic scoped privilege follows the impersonated member' do
    topic = grant_privileges(@member, 'training.topics.edit_details', topic: @topic)
    sign_in_as_admin
    post impersonate_user_path(@member.id)

    get edit_training_topic_path(topic)

    assert_response :success
  end
end
