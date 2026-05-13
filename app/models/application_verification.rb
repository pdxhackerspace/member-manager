class ApplicationVerification < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :active, -> { where(email_verified: true).where('expires_at > ?', Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :admin_search, lambda { |query|
    raw = query.to_s.strip
    if raw.blank?
      all
    else
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(raw.downcase)}%"
      where('LOWER(application_verifications.email) LIKE ?', pattern)
    end
  }

  def expired?
    expires_at < Time.current
  end

  def verified?
    email_verified? && !expired?
  end

  def verify_email!
    update!(email_verified: true, verified_at: Time.current)
  end

  def extend_expiration_by!(duration)
    update!(expires_at: [expires_at, Time.current].max + duration)
  end

  def status_display
    return 'Expired' if expired?
    return 'Verified' if email_verified?

    'Email sent'
  end

  private

  def generate_token
    self.token ||= SecureRandom.alphanumeric(32)
  end

  def set_expiry
    self.expires_at ||= MembershipSetting.application_verification_expiry_hours.hours.from_now
  end
end
