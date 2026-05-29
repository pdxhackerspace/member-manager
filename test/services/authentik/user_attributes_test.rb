require 'test_helper'

module Authentik
  class UserAttributesTest < ActiveSupport::TestCase
    test 'for includes member manager and slack fields' do
      user = users(:two)
      user.update_columns(slack_id: 'U123SLACK', slack_handle: 'alice')

      assert_equal(
        {
          'member_manager_id' => user.id.to_s,
          'slack_user_id' => 'U123SLACK',
          'slack_handle' => 'alice'
        },
        UserAttributes.for(user)
      )
    end

    test 'for uses empty strings when slack fields are blank' do
      user = users(:two)
      user.update_columns(slack_id: nil, slack_handle: nil)

      assert_equal(
        {
          'member_manager_id' => user.id.to_s,
          'slack_user_id' => '',
          'slack_handle' => ''
        },
        UserAttributes.for(user)
      )
    end

    test 'for falls back to linked slack user when member slack columns are blank' do
      user = users(:two)
      slack_user = slack_users(:with_dept)
      user.update_columns(slack_id: nil, slack_handle: nil)
      slack_user.update!(user_id: user.id)

      assert_equal(
        {
          'member_manager_id' => user.id.to_s,
          'slack_user_id' => slack_user.slack_id,
          'slack_handle' => slack_user.username
        },
        UserAttributes.for(user)
      )
    end
  end
end
