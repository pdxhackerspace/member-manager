module Slack
  class UserSyncJob < ApplicationJob
    queue_as :default

    def perform(update_members: false)
      unless MemberSource.enabled?('slack')
        Rails.logger.info('Slack source is disabled — skipping sync.')
        return
      end

      ensure_configured!
      result = UserSynchronizer.new.call(update_members: update_members)
      Rails.logger.info(
        "Slack user sync completed (#{result.synced_count} users, #{result.linked_count} linked" \
        "#{member_update_summary(result, update_members)})."
      )
    rescue StandardError => e
      Rails.logger.error("Slack user sync failed: #{e.class} #{e.message}")
      raise
    end

    private

    def ensure_configured!
      raise 'SLACK_API_TOKEN is missing' unless SlackConfig.configured?
    end

    def member_update_summary(result, update_members)
      return '' unless update_members

      parts = []
      parts << "#{result.updated_count} updated" if result.updated_count.positive?
      parts << "#{result.created_count} created" if result.created_count.positive?
      parts << "#{result.create_failed_count} create failed" if result.create_failed_count.positive?
      parts.any? ? ", #{parts.join(', ')}" : ''
    end
  end
end
