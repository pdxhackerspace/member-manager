require 'test_helper'

class PrivilegeUiHelperTest < ActionView::TestCase
  include PrivilegeUiHelper

  setup do
    @member = users(:one)
    @topic = training_topics(:laser_cutting)
    @subject = nil
  end

  # The helper reaches privileges through the controller's can?/can_for_any_topic?, which
  # this stands in for so the helper can be exercised without a request.
  def can?(privilege, topic: nil)
    @subject&.can?(privilege, topic: topic) || false
  end

  def can_for_any_topic?(privilege)
    @subject&.can_for_any_topic?(privilege) || false
  end

  test 'renders nothing without the privilege' do
    @subject = @member

    assert_nil gate(:'members.ban') { 'Ban' }
  end

  test 'renders the block with the privilege' do
    grant_privileges(@member, 'members.ban')
    @subject = @member

    assert_equal 'Ban', gate(:'members.ban') { 'Ban' }
  end

  test 'renders nothing when nobody is signed in' do
    @subject = nil

    assert_nil gate(:'members.ban') { 'Ban' }
  end

  test 'an administrator sees everything' do
    @subject = users(:two).tap { |user| user.update!(is_admin: true) }

    assert_equal 'Ban', gate(:'members.ban') { 'Ban' }
  end

  test 'a topic scoped privilege needs its topic' do
    topic = grant_privileges(@member, 'training.topics.edit_details', topic: @topic)
    @subject = @member

    assert_nil gate(:'training.topics.edit_details') { 'Edit' }
    assert_equal 'Edit', gate(:'training.topics.edit_details', topic: topic) { 'Edit' }
  end

  test 'any_topic answers without a topic in hand' do
    grant_privileges(@member, 'training.record', topic: @topic)
    @subject = @member

    assert_equal 'Record', gate(:'training.record', any_topic: true) { 'Record' }
  end

  test 'any_topic is false for a privilege held nowhere' do
    @subject = @member

    assert_nil gate(:'training.record', any_topic: true) { 'Record' }
  end
end
