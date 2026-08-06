class NagSetting < ApplicationRecord
  CATALOG = {
    'slack_signup' => {
      name: 'Slack signup reminder',
      description: 'Gentle reminder to active members without a linked Slack account.',
      enabled: false
    }
  }.freeze

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }

  def self.enabled?(key)
    find_by(key: key)&.enabled? == true
  end

  def self.seed_defaults!
    CATALOG.each do |key, attrs|
      find_or_create_by!(key: key) do |setting|
        setting.assign_attributes(attrs)
      end
    end
  end
end
