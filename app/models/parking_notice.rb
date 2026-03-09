class ParkingNotice < ApplicationRecord
  NOTICE_TYPES = %w[permit ticket].freeze
  STATUSES = %w[active expired cleared].freeze

  belongs_to :user, optional: true
  belongs_to :issued_by, class_name: 'User'
  belongs_to :cleared_by, class_name: 'User', optional: true

  has_many_attached :photos

  validates :notice_type, presence: true, inclusion: { in: NOTICE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :expires_at, presence: true
  validates :user, presence: true, if: :permit?

  scope :permits, -> { where(notice_type: 'permit') }
  scope :tickets, -> { where(notice_type: 'ticket') }
  scope :active_notices, -> { where(status: 'active') }
  scope :expired_notices, -> { where(status: 'expired') }
  scope :cleared_notices, -> { where(status: 'cleared') }
  scope :not_cleared, -> { where.not(status: 'cleared') }
  scope :needing_expiration, -> { active_notices.where(expires_at: ..Time.current) }
  scope :ordered, -> { order(expires_at: :asc) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  def permit?
    notice_type == 'permit'
  end

  def ticket?
    notice_type == 'ticket'
  end

  def active?
    status == 'active'
  end

  def expired?
    status == 'expired'
  end

  def cleared?
    status == 'cleared'
  end

  def past_expiration?
    expires_at <= Time.current
  end

  def notice_type_display
    notice_type&.capitalize
  end

  def status_display
    status&.capitalize
  end

  def badge_color
    permit? ? 'success' : 'danger'
  end

  def status_badge_color
    case status
    when 'active' then 'primary'
    when 'expired' then 'danger'
    when 'cleared' then 'secondary'
    else 'secondary'
    end
  end

  def location_display
    parts = []
    parts << location if location.present?
    parts << location_detail if location_detail.present?
    parts.join(' — ')
  end

  def clear!(admin)
    update!(
      status: 'cleared',
      cleared_at: Time.current,
      cleared_by: admin
    )
  end

  def expire!
    update!(status: 'expired')
  end

  def record_journal_entry!(action_name, actor: nil)
    return unless user.present?

    Journal.create!(
      user: user,
      actor_user: actor,
      action: action_name,
      changes_json: {
        'parking_notice' => {
          'id' => id,
          'notice_type' => notice_type,
          'location' => location_display,
          'expires_at' => expires_at.strftime('%B %d, %Y'),
          'description' => description.to_s.truncate(100)
        }
      },
      changed_at: Time.current,
      highlight: true
    )
  end

  def enqueue_notification!(template_key)
    return unless user.present? && user.email.present?

    QueuedMail.enqueue(
      template_key,
      user,
      reason: "Parking #{notice_type}: #{template_key.humanize}",
      location: location_display,
      location_detail: location_detail.to_s,
      description: description.to_s,
      expires_at: expires_at.strftime('%B %d, %Y'),
      notice_type: notice_type_display
    )
  end
end
