require 'test_helper'

class TrainingRequestTest < ActiveSupport::TestCase
  test 'cannot create duplicate pending request for same user and topic' do
    existing = training_requests(:pending_laser_request)

    duplicate = TrainingRequest.new(
      user: existing.user,
      training_topic: existing.training_topic,
      share_contact_info: true,
      status: 'pending'
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:training_topic_id], 'already has an active request for this member'
  end

  test 'allows new request for same user and topic when previous request was responded' do
    responded = training_requests(:responded_woodworking_request)
    request = TrainingRequest.new(
      user: responded.user,
      training_topic: responded.training_topic,
      share_contact_info: true,
      status: 'pending'
    )

    assert request.valid?
  end

  test 'dismiss! records the dismissal time and is idempotent' do
    request = training_requests(:responded_woodworking_request)
    assert_not request.dismissed?

    request.dismiss!
    request.reload

    assert request.dismissed?
    assert_not_nil request.dismissed_at

    original_time = request.dismissed_at
    request.dismiss!
    assert_equal original_time, request.reload.dismissed_at
  end

  test 'not_dismissed and dismissed scopes partition by dismissal' do
    dismissed = training_requests(:responded_woodworking_request)
    dismissed.dismiss!
    active = training_requests(:pending_laser_request)

    assert_includes TrainingRequest.not_dismissed, active
    assert_not_includes TrainingRequest.not_dismissed, dismissed
    assert_includes TrainingRequest.dismissed, dismissed
    assert_not_includes TrainingRequest.dismissed, active
  end

  test 'awaiting_member_acknowledgement returns responded requests that are not dismissed' do
    responded = training_requests(:responded_woodworking_request)
    pending = training_requests(:pending_laser_request)

    assert_includes TrainingRequest.awaiting_member_acknowledgement, responded
    assert_not_includes TrainingRequest.awaiting_member_acknowledgement, pending

    responded.dismiss!
    assert_not_includes TrainingRequest.awaiting_member_acknowledgement, responded
  end
end
