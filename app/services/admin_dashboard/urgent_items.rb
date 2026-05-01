# frozen_string_literal: true

module AdminDashboard
  # Builds the urgent tier shown on the admin dashboard for reuse in notifications.
  class UrgentItems
    include Rails.application.routes.url_helpers

    Item = Data.define(:id, :title, :detail, :url)

    def self.call(user: nil)
      new(user: user).call
    end

    def initialize(user: nil)
      @user = user
    end

    def call
      [
        unread_messages_item,
        access_controller_item,
        payment_processors_item,
        authentik_item,
        ai_ollama_item,
        printers_item
      ].compact
    end

    private

    attr_reader :user

    def unread_messages_item
      return nil unless user

      count = Message.folder(user, :unread).count
      return nil if count.zero?

      item(
        :unread_messages,
        "#{count} unread #{'message'.pluralize(count)}",
        'Your Member Manager inbox has unread messages.',
        messages_path(folder: :unread)
      )
    end

    def access_controller_item
      enabled_controllers = AccessController.enabled
      offline_count = enabled_controllers.where(ping_status: 'failed').count
      sync_failed_count = enabled_controllers.where(sync_status: 'failed').count
      backup_failed_count = enabled_controllers.where(backup_status: 'failed').count
      issue_count = offline_count + sync_failed_count + backup_failed_count
      return nil if issue_count.zero?

      details = []
      details << "#{offline_count} offline" if offline_count.positive?
      details << "#{sync_failed_count} sync failed" if sync_failed_count.positive?
      details << "#{backup_failed_count} backup failed" if backup_failed_count.positive?

      item(
        :ac_issues,
        "#{issue_count} access controller #{'issue'.pluralize(issue_count)}",
        details.join(', '),
        access_controllers_path
      )
    end

    def payment_processors_item
      unhealthy = PaymentProcessor.enabled.where(sync_status: %w[degraded failing]).order(:name).to_a
      return nil if unhealthy.empty?

      item(
        :payment_processors,
        "#{unhealthy.size} payment processor #{'integration'.pluralize(unhealthy.size)} with sync problems",
        unhealthy.map { |processor| "#{processor.name} (#{processor.status_label})" }.join(', '),
        payment_processors_path
      )
    end

    def authentik_item
      source = MemberSource.find_by(key: 'authentik')
      api_urgent = !AuthentikConfig.api_ready? && (AuthentikConfig.enabled_for_login? || source&.enabled?)

      if api_urgent
        return item(
          :authentik,
          'Authentik API integration is not configured',
          'Set AUTHENTIK_TOKEN and a valid API base URL so Member Manager can call Authentik.',
          authentik_webhooks_path
        )
      end

      return nil unless source&.enabled? && source.sync_status.in?(%w[degraded failing])

      item(
        :authentik,
        "Authentik sync is #{source.sync_status_label.downcase}",
        source.last_error_message.to_s.truncate(200),
        member_source_path(source)
      )
    end

    def ai_ollama_item
      unhealthy = AiOllamaProfile.ordered.select(&:urgent_health_issue?)
      return nil if unhealthy.empty?

      item(
        :ai_ollama,
        "AI Services: #{unhealthy.size} unhealthy #{'service'.pluralize(unhealthy.size)}",
        unhealthy.map { |profile| "#{profile.name}: #{profile.last_health_error}" }.join('; ').truncate(300),
        ai_ollama_profiles_path
      )
    end

    def printers_item
      unhealthy = Printer.ordered.select(&:urgent_health_issue?)
      return nil if unhealthy.empty?

      item(
        :printers,
        "Printers: #{unhealthy.size} unhealthy #{'printer'.pluralize(unhealthy.size)}",
        unhealthy.map { |printer| "#{printer.name}: #{printer.last_health_error}" }.join('; ').truncate(300),
        printers_path
      )
    end

    def item(id, title, detail, path)
      Item.new(id, title, detail, absolute_url(path))
    end

    def absolute_url(path)
      "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3000').chomp('/')}#{path}"
    end
  end
end
