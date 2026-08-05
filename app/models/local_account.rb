class LocalAccount < ApplicationRecord
  include SensitiveFields

  encrypts_sensitive_string :email
  has_email_lookup :email, digest_column: :email_lookup_digest

  has_secure_password

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email_lookup_digest, uniqueness: true, allow_blank: true
  validate :email_is_unique
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :password_digest, presence: true

  scope :active, -> { where(active: true) }

  def display_name
    full_name.presence || email
  end

  private

  def email_is_unique
    return if email.blank?

    relation = self.class.by_email(email)
    relation = relation.where.not(id: id) if persisted?
    errors.add(:email, :taken) if relation.exists?
  end
end
