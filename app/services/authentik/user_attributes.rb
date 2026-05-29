module Authentik
  class UserAttributes
    def self.for(user)
      slack_user = user.slack_user
      slack_id = user.slack_id.presence || slack_user&.slack_id
      slack_handle = user.slack_handle.presence || slack_user&.username

      {
        'member_manager_id' => user.id.to_s,
        'slack_user_id' => slack_id.presence || '',
        'slack_handle' => slack_handle.presence || '',
        'trained_on' => trained_on_topics_for(user),
        'can_train' => can_train_topics_for(user)
      }
    end

    def self.supplemental_sync_user_ids
      ids = []
      ids.concat(User.joins(:slack_user).pluck(:id))
      ids.concat(Training.distinct.pluck(:trainee_id))
      ids.concat(TrainerCapability.distinct.pluck(:user_id))
      ids.compact.uniq
    end

    def self.trained_on_topics_for(user)
      user.trainings_as_trainee
          .joins(:training_topic)
          .distinct
          .order('training_topics.name')
          .pluck('training_topics.name')
    end

    def self.can_train_topics_for(user)
      user.trainer_capabilities
          .joins(:training_topic)
          .distinct
          .order('training_topics.name')
          .pluck('training_topics.name')
    end
  end
end
