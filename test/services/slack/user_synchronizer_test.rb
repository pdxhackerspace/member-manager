require 'test_helper'

module Slack
  class UserSynchronizerTest < ActiveSupport::TestCase
    StubClient = Struct.new(:users) do
      def list_users
        users
      end
    end

    test 'refreshes slack users and links matching member without copying profile data' do
      user = users(:two)
      user.update_columns(
        email: 'member-sync@example.com',
        aliases: [],
        slack_id: nil,
        slack_handle: nil,
        pronouns: nil,
        bio: nil,
        avatar: nil
      )

      client = StubClient.new(
        [
          {
            slack_id: 'U-MEMBER-SYNC',
            team_id: 'T123',
            username: 'slackmember',
            real_name: user.full_name,
            display_name: 'Slack Member',
            email: user.email,
            pronouns: 'they/them',
            title: 'Slack title',
            is_bot: false,
            deleted: false,
            raw_attributes: {
              'profile' => { 'image_original' => 'yes', 'image_192' => 'https://example.com/avatar.png' }
            },
            last_synced_at: Time.current
          }
        ]
      )

      Slack::UserSynchronizer.new(client: client).call

      slack_user = SlackUser.find_by!(slack_id: 'U-MEMBER-SYNC')
      assert_equal user.id, slack_user.user_id

      user.reload
      assert_nil user.slack_id
      assert_nil user.slack_handle
      assert_nil user.pronouns
      assert_nil user.bio
      assert_nil user.avatar
      assert_empty user.aliases
    end

    # The run shares one transaction, so a duplicate address rejected by the database must not
    # abort the members queued behind it.
    test 'a member whose address is already taken does not stop the rest of the sync' do
      SlackUser.create!(slack_id: 'U-INCUMBENT', email: 'contested@example.com')

      client = StubClient.new(
        [
          { slack_id: 'U-DUPLICATE', email: 'contested@example.com', real_name: 'Duplicate Address',
            is_bot: false, deleted: false },
          { slack_id: 'U-FOLLOWER', email: 'follower@example.com', real_name: 'Queued Behind',
            is_bot: false, deleted: false }
        ]
      )

      synchronizer = Slack::UserSynchronizer.new(client: client, logger: Logger.new(File::NULL))

      assert_nothing_raised { synchronizer.call }
      assert_not SlackUser.exists?(slack_id: 'U-DUPLICATE')
      assert SlackUser.exists?(slack_id: 'U-FOLLOWER')
    end
  end
end
