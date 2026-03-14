class ApplicationVerification < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :active, -> { where(email_verified: true).where('expires_at > ?', Time.current) }

  def expired?
    expires_at < Time.current
  end

  def verified?
    email_verified? && !expired?
  end

  def verify_email!
    update!(email_verified: true, verified_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.alphanumeric(32)
  end

  def set_expiry
    self.expires_at ||= MembershipSetting.application_verification_expiry_hours.hours.from_now
  end
end
