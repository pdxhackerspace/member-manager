class SlackUser < ApplicationRecord
  belongs_to :user, optional: true
  validates :slack_id, presence: true, uniqueness: true
  validates :email,
            allow_blank: true,
            uniqueness: true,
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              allow_blank: true
            }

  ACTIVE_WINDOW = 1.year

  scope :human, -> { where(is_bot: false) }
  scope :deactivated, -> { where(deleted: true) }
  scope :not_deactivated, -> { where(deleted: false) }
  scope :inactive, lambda {
    not_deactivated.where('last_active_at < ? OR last_active_at IS NULL', inactive_cutoff)
  }
  scope :active, -> { not_deactivated.where(last_active_at: inactive_cutoff..) }
  scope :with_attribute, ->(key, value) { where('raw_attributes ->> ? = ?', key.to_s, value.to_s) }

  def display_name
    display_name = self[:display_name].presence || real_name.presence || username.presence
    display_name || slack_id
  end

  def self.inactive_cutoff
    ACTIVE_WINDOW.ago
  end

  def inactive?
    !deleted? && (last_active_at.blank? || last_active_at < self.class.inactive_cutoff)
  end

  def active?
    !deleted? && !inactive?
  end

  after_commit :enqueue_authentik_sync_for_linked_users, if: :saved_change_to_user_id?

  private

  def enqueue_authentik_sync_for_linked_users
    return if Current.skip_authentik_sync

    previous_user_id, current_user_id = saved_change_to_user_id
    [previous_user_id, current_user_id].compact.uniq.each do |linked_user_id|
      Authentik::UserSyncJob.perform_later(linked_user_id)
    end
  end
end
