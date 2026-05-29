class TrainerCapability < ApplicationRecord
  belongs_to :user
  belongs_to :training_topic

  validates :user_id, uniqueness: { scope: :training_topic_id }

  after_create :sync_can_train_group
  after_destroy :sync_can_train_group
  after_commit :enqueue_trainer_authentik_sync, on: %i[create destroy]

  private

  def enqueue_trainer_authentik_sync
    return if Current.skip_authentik_sync

    Authentik::UserSyncJob.perform_later(user_id, %w[can_train])
  end

  def sync_can_train_group
    Authentik::ApplicationGroupMembershipSyncJob.perform_later(%w[can_train])
  end
end
