module GoogleSheets
  class SyncJob < ApplicationJob
    queue_as :default

    def perform
      unless MemberSource.enabled?('sheet')
        Rails.logger.info('Google Sheet source is disabled — skipping sync.')
        return
      end

      count = GoogleSheets::EntrySynchronizer.new.call
      Rails.logger.info("Synced #{count} Google Sheet entries.")
    rescue StandardError => e
      Rails.logger.error("Google Sheets sync failed: #{e.class} #{e.message}")
      raise
    end
  end
end
