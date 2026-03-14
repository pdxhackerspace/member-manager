module Slack
  class UserSyncJob < ApplicationJob
    queue_as :default

    def perform
      unless MemberSource.enabled?('slack')
        Rails.logger.info('Slack source is disabled — skipping sync.')
        return
      end

      ensure_configured!
      synced_count = UserSynchronizer.new.call
      Rails.logger.info("Slack user sync completed (#{synced_count} users).")
    rescue StandardError => e
      Rails.logger.error("Slack user sync failed: #{e.class} #{e.message}")
      raise
    end

    private

    def ensure_configured!
      raise 'SLACK_API_TOKEN is missing' unless SlackConfig.configured?
    end
  end
end
