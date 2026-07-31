require 'test_helper'

class UserParkingMemberLabelTest < ActiveSupport::TestCase
  test 'parking_member_label returns username when no slack handle' do
    user = users(:one)

    assert_equal user.username, user.parking_member_label
  end

  test 'parking_member_label includes slack_handle column when present' do
    user = users(:one)
    user.update!(slack_handle: 'shopuser')

    assert_equal "#{user.username} @shopuser", user.parking_member_label
  end

  test 'parking_member_label falls back to linked slack_user username' do
    user = users(:one)
    slack_user = slack_users(:with_dept)
    slack_user.update!(user: user)

    assert_equal "#{user.username} @#{slack_user.username}", user.parking_member_label
  end

  test 'slack_handle column takes precedence over linked slack_user' do
    user = users(:one)
    user.update!(slack_handle: 'preferred')
    slack_users(:with_dept).update!(user: user, username: 'other')

    assert_equal "#{user.username} @preferred", user.parking_member_label
  end
end
