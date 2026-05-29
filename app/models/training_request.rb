class TrainingRequest < ApplicationRecord
  STATUSES = %w[pending responded].freeze

  belongs_to :user
  belongs_to :training_topic
  belongs_to :responded_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :share_contact_info, inclusion: { in: [true, false] }
  validates :training_topic_id, uniqueness: {
    scope: :user_id,
    conditions: -> { where(status: 'pending') },
    message: 'already has an active request for this member'
  }

  scope :pending, -> { where(status: 'pending') }
  scope :responded, -> { where(status: 'responded') }
  scope :newest_first, -> { order(created_at: :desc) }

  def pending?
    status == 'pending'
  end

  def responded?
    status == 'responded'
  end

  def respond!(responder)
    update!(status: 'responded', responded_by: responder, responded_at: Time.current)
  end

  def self.clear_pending_for!(user:, training_topic:, responded_by: nil)
    pending.where(user: user, training_topic: training_topic).find_each do |request|
      request.update!(status: 'responded', responded_by: responded_by, responded_at: Time.current)
    end
  end
end
