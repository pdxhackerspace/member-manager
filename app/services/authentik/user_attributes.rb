module Authentik
  class UserAttributes
    def self.for(user)
      slack_user = user.slack_user
      slack_id = user.slack_id.presence || slack_user&.slack_id
      slack_handle = user.slack_handle.presence || slack_user&.username

      {
        'member_manager_id' => user.id.to_s,
        'slack_user_id' => slack_id.presence || '',
        'slack_handle' => slack_handle.presence || ''
      }
    end
  end
end
