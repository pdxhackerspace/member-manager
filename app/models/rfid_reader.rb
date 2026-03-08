class RfidReader < ApplicationRecord
  validates :name, presence: true
  validates :key, presence: true, uniqueness: true, length: { is: 32 }

  before_validation :generate_key, on: :create

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
      break key unless self.class.exists?(key: key)
    end
  end
end
