# frozen_string_literal: true

# Tracks recent Action Mailer delivery failures so health checks and the admin
# dashboard can reflect SMTP problems even when a cached connection probe succeeded.
class MailerDeliveryMonitor
  FAILURES_KEY = 'mailer_delivery_monitor:failures:v1'
  FAILURE_WINDOW = 15.minutes
  MAX_FAILURES = 20

  def self.record_failure!(error, source: nil)
    Rails.cache.delete(MailerHealthCheck::CACHE_KEY)

    failures = read_failures
    failures << {
      'at' => Time.current.iso8601(6),
      'error_class' => error.class.name,
      'message' => error.message.to_s,
      'source' => source.to_s.presence
    }
    failures = failures.last(MAX_FAILURES)
    Rails.cache.write(FAILURES_KEY, failures, expires_in: 1.day)

    Rails.logger.warn(
      "[MailerDeliveryMonitor] delivery failed source=#{source || 'unknown'} " \
      "#{error.class}: #{error.message}"
    )
  end

  def self.unhealthy_result
    recent = recent_failures
    return nil if recent.empty?

    MailerHealthCheck::Result.new('unhealthy', failure_summary(recent), Time.current)
  end

  def self.recent_failures(within: FAILURE_WINDOW)
    cutoff = Time.current - within
    read_failures.filter_map do |entry|
      at = Time.zone.parse(entry['at'].to_s)
      next if at.nil? || at < cutoff

      entry
    end
  end

  def self.read_failures
    Array(Rails.cache.read(FAILURES_KEY))
  end
  private_class_method :read_failures

  def self.failure_summary(recent)
    latest = recent.last
    count = recent.size
    detail = "#{latest['error_class']}: #{latest['message']}"
    detail = detail.truncate(240)

    if count == 1
      "Recent mail delivery failed (#{detail})"
    else
      "#{count} mail deliveries failed in the last #{FAILURE_WINDOW.in_minutes.to_i} minutes " \
        "(latest: #{detail})"
    end
  end
  private_class_method :failure_summary
end
