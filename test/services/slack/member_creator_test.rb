require 'test_helper'

module Slack
  class MemberCreatorTest < ActiveSupport::TestCase
    test 'creates and links a member from a slack user' do
      slack_user = slack_users(:with_other_dept)
      slack_user.update_columns(user_id: nil)

      assert_difference 'User.count', 1 do
        result = MemberCreator.call(slack_user: slack_user)
        assert result.success?
        assert_equal slack_user.id, result.user.slack_user.id
      end

      slack_user.reload
      new_user = User.find(slack_user.user_id)
      assert_equal 'Mary Jane', new_user.full_name
      assert_equal slack_user.email, new_user.email
      assert_equal slack_user.slack_id, new_user.slack_id
    end

    test 'rejects already-linked slack users' do
      slack_user = slack_users(:with_dept)
      slack_user.update_columns(user_id: users(:one).id)

      assert_no_difference 'User.count' do
        result = MemberCreator.call(slack_user: slack_user)
        assert_not result.success?
        assert_match(/already linked/, result.message)
      end
    end
  end
end
