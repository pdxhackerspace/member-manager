require 'test_helper'

class TrainingHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'member sees their own training history on the training tab' do
    sign_in_as_member
    member = local_member
    Training.create!(
      trainee: member,
      training_topic: training_topics(:woodworking),
      trainer: users(:one),
      trained_at: Time.current
    )

    get user_path(member, tab: :training_history)

    assert_response :success
    assert_match 'Your training', response.body
    assert_match 'Woodworking', response.body
  end

  test 'trainer sees training records for topics they can teach' do
    trainer = sign_in_as_trainer
    topic = training_topics(:laser_cutting)
    TrainerCapability.find_or_create_by!(user: trainer, training_topic: topic)
    Training.create!(trainee: users(:one), training_topic: topic, trainer: trainer, trained_at: Time.current)

    get user_path(trainer, tab: :training_history)

    assert_response :success
    assert_match 'Training in topics you can teach', response.body
    assert_match users(:one).display_name, response.body
  end

  test 'non-trainer member does not see the trainer history section' do
    sign_in_as_member
    member = local_member

    get user_path(member, tab: :training_history)

    assert_response :success
    assert_no_match(/Training in topics you can teach/, response.body)
  end

  test 'training tab surfaces completed requests with a dismiss action and hides dismissed ones' do
    sign_in_as_member
    member = local_member
    completed = TrainingRequest.create!(
      user: member,
      training_topic: training_topics(:woodworking),
      share_contact_info: true,
      status: 'responded',
      responded_at: Time.current
    )

    get user_path(member, tab: :training_history)
    assert_response :success
    assert_match 'Training completed', response.body
    assert_match dismiss_training_request_path(completed), response.body

    completed.dismiss!

    get user_path(member, tab: :training_history)
    assert_response :success
    assert_no_match(/Training completed/, response.body)
  end

  test 'admin dashboard renders the member training history tab' do
    sign_in_as_admin

    get root_path(tab: :training_history)

    assert_response :success
    assert_match 'Your training', response.body
  end

  private

  def local_member
    User.find_by(authentik_id: "local:#{local_accounts(:regular_member).id}")
  end

  def sign_in_as_member
    post local_login_path, params: {
      session: { email: local_accounts(:regular_member).email, password: 'memberpassword123' }
    }
  end

  def sign_in_as_trainer
    post local_login_path, params: {
      session: { email: local_accounts(:trainer_account).email, password: 'trainerpassword123' }
    }
    User.find_by(authentik_id: "local:#{local_accounts(:trainer_account).id}")
  end

  def sign_in_as_admin
    post local_login_path, params: {
      session: { email: local_accounts(:active_admin).email, password: 'localpassword123' }
    }
    User.find_by(authentik_id: "local:#{local_accounts(:active_admin).id}")
  end
end
