class Training < ApplicationRecord
  belongs_to :trainee, class_name: 'User'
  belongs_to :trainer, class_name: 'User', optional: true
  belongs_to :training_topic

  validates :trained_at, presence: true

  scope :recent, -> { order(trained_at: :desc) }

  after_create :sync_trained_in_group, :clear_pending_training_requests
  after_destroy :sync_trained_in_group

  private

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
