require 'test_helper'

class TrainingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @topic = training_topics(:laser_cutting)
    @trainee = users(:member_with_local_account)
    @trainer = users(:one)
    @request = training_requests(:pending_laser_request)
  end

  test 'creating training for a topic required by an access controller type enqueues a sync' do
    assert_enqueued_with(job: AccessControllerTrainingSyncJob, args: [@topic.id]) do
      Training.create!(trainee: @trainee, trainer: @trainer, training_topic: @topic, trained_at: Time.current)
    end
  end

  test 'removing training for a required topic enqueues a sync' do
    training = Training.create!(trainee: @trainee, trainer: @trainer, training_topic: @topic, trained_at: Time.current)

    assert_enqueued_with(job: AccessControllerTrainingSyncJob, args: [@topic.id]) do
      training.destroy!
    end
  end

  test 'training change for a topic no access controller requires does not enqueue a sync' do
    woodworking = training_topics(:woodworking)

    assert_no_enqueued_jobs only: AccessControllerTrainingSyncJob do
      Training.create!(trainee: @trainee, trainer: @trainer, training_topic: woodworking, trained_at: Time.current)
    end
  end

  test 'creating training clears pending request for same user and topic' do
    assert @request.pending?

    Training.create!(
      trainee: @trainee,
      trainer: @trainer,
      training_topic: @topic,
      trained_at: Time.current
    )

    @request.reload
    assert @request.responded?
    assert_equal @trainer, @request.responded_by
    assert_not_nil @request.responded_at
  end

  test 'creating training does not affect pending requests for other topics' do
    other_topic = training_topics(:woodworking)
    other_request = TrainingRequest.create!(
      user: @trainee,
      training_topic: other_topic,
      share_contact_info: true,
      status: 'pending'
    )

    Training.create!(
      trainee: @trainee,
      trainer: @trainer,
      training_topic: @topic,
      trained_at: Time.current
    )

    assert @request.reload.responded?
    assert other_request.reload.pending?
  end

  test 'creating training does not affect pending requests for other users' do
    other_user = users(:no_email)
    other_request = TrainingRequest.create!(
      user: other_user,
      training_topic: @topic,
      share_contact_info: true,
      status: 'pending'
    )

    Training.create!(
      trainee: @trainee,
      trainer: @trainer,
      training_topic: @topic,
      trained_at: Time.current
    )

    assert @request.reload.responded?
    assert other_request.reload.pending?
  end
end
