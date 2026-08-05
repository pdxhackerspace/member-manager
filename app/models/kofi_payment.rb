class KofiPayment < ApplicationRecord
  include NormalizesEmail
  include SensitiveFields

  encrypts_sensitive_string :email
  encrypts_sensitive_json :raw_attributes
  has_email_lookup :email, digest_column: :email_lookup_digest
  normalizes_email_field :email

  belongs_to :user, optional: true
  belongs_to :sheet_entry, optional: true
  has_many :payment_events, dependent: :nullify

  validates :kofi_transaction_id, presence: true, uniqueness: true

  scope :ordered, -> { order(timestamp: :desc, created_at: :desc) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_sheet_entry, ->(entry) { where(sheet_entry_id: entry.id) }

  def amount_with_currency
    return nil if amount.blank?

    "#{format('%.2f', amount)} #{currency}"
  end

  def identifier
    kofi_transaction_id
  end

  def processed_time
    timestamp
  end
end
