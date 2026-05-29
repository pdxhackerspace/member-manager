class Training < ApplicationRecord
  belongs_to :trainee, class_name: 'User'
  belongs_to :trainer, class_name: 'User', optional: true
  belongs_to :training_topic

  validates :trained_at, presence: true

  scope :recent, -> { order(trained_at: :desc) }

  after_create :sync_trained_in_group, :clear_pending_training_requests
  after_destroy :sync_trained_in_group
  after_commit :enqueue_trainee_authentik_sync, on: %i[create destroy]

  private

  def enqueue_trainee_authentik_sync
    return if Current.skip_authentik_sync
    return if trainee_id.blank?

    Authentik::UserSyncJob.perform_later(trainee_id, %w[trained_on])
  end

  def sync_trained_in_group
    Authentik::ApplicationGroupMembershipSyncJob.perform_later(%w[trained_in])
  end

  def clear_pending_training_requests
    TrainingRequest.clear_pending_for!(
      user: trainee,
      training_topic: training_topic,
      responded_by: trainer
    )
  end
end
