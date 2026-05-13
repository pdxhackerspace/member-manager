class RfidReader < ApplicationRecord
  include SensitiveFields

  validates :name, presence: true
  validates :key, presence: true, length: { is: 32 }
  validates :key_lookup_digest, uniqueness: true, allow_blank: true

  before_validation :generate_key, on: :create
  before_validation :set_key_lookup_digest
  before_save :set_key_lookup_digest

  def self.lookup_by_key(key)
    digest = SensitiveData.email_digest(key)
    return nil if digest.blank?

    where(key_lookup_digest: digest).or(where(key: key.to_s.strip)).first
  end

  def key
    ciphertext = self[:key_ciphertext] if has_attribute?(:key_ciphertext)
    return SensitiveData.decode_string(ciphertext) if ciphertext.present?

    self[:key]
  end

  def key=(value)
    normalized = value.to_s.strip.presence
    if normalized.blank?
      self[:key] = nil
      self[:key_ciphertext] = nil if has_attribute?(:key_ciphertext)
      return
    end

    self[:key_ciphertext] = SensitiveData.encode_string(normalized) if has_attribute?(:key_ciphertext)
    self[:key] = "enc-#{SensitiveData.email_digest(normalized)[0, 28]}"
  end

  def generate_key!
    self.key = generate_unique_key
    save!
  end

  private

  def generate_key
    self.key ||= generate_unique_key
  end

  def generate_unique_key
    loop do
      key = SecureRandom.alphanumeric(32).downcase
      break key unless self.class.lookup_by_key(key)
    end
  end

  def set_key_lookup_digest
    self.key_lookup_digest = SensitiveData.email_digest(key) if has_attribute?(:key_lookup_digest)
  end
end
