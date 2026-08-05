require 'test_helper'

# Impersonation lets an administrator look at the app as another member. It must never lend
# that member's authority to the session: every gate resolves against the real signed-in
# account, so what the session may do is decided by who is really logged in.
class ImpersonationPrivilegesTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    @topic = training_topics(:laser_cutting)
    @trainee = users(:no_email)
    @target = users(:one)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'a session impersonating a trainer cannot record training' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    impersonate_without_admin(@target)

    assert_no_difference 'Training.count' do
      post add_training_path(user_id: @trainee.id, topic_id: @topic.id)
    end
  end

  test 'a session impersonating a trainer cannot record training in bulk' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    impersonate_without_admin(@target)

    assert_no_difference 'Training.count' do
      post record_training_path, params: {
        training_topic_id: @topic.id,
        trained_at: Date.current.iso8601,
        trainee_ids: [@trainee.id]
      }
    end
  end

  test 'a session impersonating a trainer cannot reach the record training page' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    impersonate_without_admin(@target)

    get record_training_path

    assert_redirected_to root_path
  end

  test 'a session impersonating a director cannot appoint a trainer' do
    grant_privileges(@target, 'training.grant_trainer')
    impersonate_without_admin(@target)

    assert_no_difference 'TrainerCapability.count' do
      post add_trainer_capability_path(user_id: @trainee.id, topic_id: @topic.id)
    end
  end

  test 'a session impersonating a trainer cannot answer that trainer\'s request queue' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    request = TrainingRequest.create!(user: @trainee, training_topic: @topic,
                                      share_contact_info: true, status: 'pending')
    impersonate_without_admin(@target)

    assert_no_difference 'Training.count' do
      post mark_trained_training_request_path(request)
    end

    assert_predicate request.reload, :pending?
  end

  test 'a session impersonating a trainer cannot upload documents for their topics' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    impersonate_without_admin(@target)

    get new_document_path

    assert_redirected_to root_path
  end

  # The rule runs both ways: authority comes from the real account, so an administrator keeps
  # theirs while viewing as someone else, and the record names the administrator who acted.
  test 'an administrator impersonating a member still records training as themselves' do
    admin = sign_in_as_admin
    post impersonate_user_path(@target.id)

    assert_difference 'Training.count', 1 do
      post add_training_path(user_id: @trainee.id, topic_id: @topic.id)
    end

    assert_equal admin, Training.find_by!(trainee: @trainee, training_topic: @topic).trainer
  end

  # Both branches of mark_trained close the request; they have to agree on who closed it.
  test 'recording training from a request names the account that acted' do
    admin = sign_in_as_admin
    request = TrainingRequest.create!(user: @trainee, training_topic: @topic,
                                      share_contact_info: true, status: 'pending')
    post impersonate_user_path(@target.id)

    post mark_trained_training_request_path(request)

    assert_predicate request.reload, :responded?
    assert_equal admin, request.responded_by
  end

  # Replying is reachable while impersonating only because the gate resolves against the real
  # account, so the reply has to carry that account too. Otherwise the member being viewed
  # appears to answer a queue they were never part of.
  test 'an administrator impersonating a member replies as themselves' do
    admin = sign_in_as_admin
    request = TrainingRequest.create!(user: @trainee, training_topic: @topic,
                                      share_contact_info: true, status: 'pending')
    post impersonate_user_path(@target.id)

    patch training_request_path(request), params: {
      training_request: { response_body: 'Happy to help — find me on Tuesday.' }
    }

    assert_predicate request.reload, :responded?
    assert_equal admin, request.responded_by
    assert_equal admin, Message.order(:created_at).last.sender
  end

  test 'a session impersonating a trainer cannot reply to that trainer\'s queue' do
    TrainerCapability.create!(user: @target, training_topic: @topic)
    request = TrainingRequest.create!(user: @trainee, training_topic: @topic,
                                      share_contact_info: true, status: 'pending')
    impersonate_without_admin(@target)

    assert_no_difference 'Message.count' do
      patch training_request_path(request), params: {
        training_request: { response_body: 'Answering a queue that is not mine.' }
      }
    end

    assert_predicate request.reload, :pending?
  end

  test 'closing an already trained request names the account that acted' do
    admin = sign_in_as_admin
    Training.create!(trainee: @trainee, trainer: @target, training_topic: @topic, trained_at: 1.day.ago)
    request = TrainingRequest.create!(user: @trainee, training_topic: @topic,
                                      share_contact_info: true, status: 'pending')
    post impersonate_user_path(@target.id)

    post mark_trained_training_request_path(request)

    assert_predicate request.reload, :responded?
    assert_equal admin, request.responded_by
  end

  private

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
    User.find_by!(authentik_id: "local:#{account.id}")
  end

  # Signs in as an administrator, starts impersonating, then drops the admin flag. The session
  # is left with a plain member as its real account and a privileged member as the impersonated
  # one — the same position an administrator demoted mid-session ends up in, and the only way to
  # hold an impersonation session without admin rights.
  def impersonate_without_admin(target)
    admin = sign_in_as_admin
    post impersonate_user_path(target.id)
    admin.update!(is_admin: false)
    admin
  end
end
