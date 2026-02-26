class Invitation < ApplicationRecord
  belongs_to :invited_by, class_name: 'User'
  belongs_to :user, optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :pending, -> { where(accepted_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where(accepted_at: nil).where('expires_at <= ?', Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :newest_first, -> { order(created_at: :desc) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def expired?
    accepted_at.nil? && expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept!(new_user)
    update!(accepted_at: Time.current, user: new_user)
  end

  def invitation_url
    "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3000')}/invite/#{token}"
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= Time.current + MembershipSetting.instance.invitation_expiry_hours.hours
  end
end
