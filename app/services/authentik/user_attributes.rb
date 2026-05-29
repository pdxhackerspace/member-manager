module Authentik
  class UserAttributes
    def self.for(user)
      {
        'member_manager_id' => user.id.to_s,
        'slack_user_id' => user.slack_id.presence || '',
        'slack_handle' => user.slack_handle.presence || ''
      }
    end
  end
end
