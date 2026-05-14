require 'net/smtp'
require 'openssl'

class MailerHealthCheck
  CACHE_KEY = 'mailer_health_check:v4'.freeze
  CACHE_TTL = 5.minutes
  DEFAULT_TIMEOUT = 5

  Result = Data.define(:status, :message, :checked_at) do
    def healthy? = status == 'healthy'
  end

  def self.call(force: false)
    return new.call if force

    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { new.call }
  end

  def call
    return unhealthy('Action Mailer is not configured to use SMTP') unless smtp_delivery_method?
    return unhealthy('SMTP is not configured') unless configured?
    return unhealthy('SMTP password is missing') if settings[:user_name].present? && settings[:password].blank?
    return unhealthy('SMTP username is missing') if settings[:password].present? && settings[:user_name].blank?

    check_smtp!
    healthy(success_message)
  rescue Net::SMTPAuthenticationError => e
    unhealthy("SMTP authentication failed: #{e.message}")
  rescue Net::OpenTimeout, Net::ReadTimeout
    unhealthy("SMTP connection timed out connecting to #{settings[:address]}:#{settings[:port] || 25}")
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::SMTPError => e
    unhealthy("#{e.class}: #{e.message}")
  end

  private

  def check_smtp!
    smtp = Net::SMTP.new(settings[:address], settings[:port] || 25)
    smtp.open_timeout = timeout
    smtp.read_timeout = timeout
    configure_tls(smtp)
    smtp.start(settings[:domain].presence || 'localhost',
               settings[:user_name],
               settings[:password],
               authentication_for_start) { true }
  end

  def configure_tls(smtp)
    return smtp.enable_tls if settings[:enable_tls]
    return smtp.enable_starttls if settings[:enable_starttls]
    return smtp.enable_starttls_auto if settings.fetch(:enable_starttls_auto, false)

    smtp.disable_starttls
  end

  def smtp_delivery_method?
    Rails.configuration.action_mailer.delivery_method.to_sym == :smtp
  end

  def configured?
    settings.is_a?(Hash) &&
      settings[:address].present? &&
      settings[:address] != 'smtp.example.com'
  end

  def settings
    @settings ||= Rails.configuration.action_mailer.smtp_settings || {}
  end

  def authentication
    (settings[:authentication].presence || :plain).to_sym
  end

  def authentication_for_start
    return nil unless authenticated?

    authentication
  end

  def authenticated?
    settings[:user_name].present? && settings[:password].present?
  end

  def success_message
    action = authenticated? ? 'Connected and authenticated' : 'Connected'

    "#{action} to #{settings[:address]}:#{settings[:port] || 25}"
  end

  def timeout
    Integer(settings.fetch(:health_check_timeout, DEFAULT_TIMEOUT))
  rescue ArgumentError, TypeError
    DEFAULT_TIMEOUT
  end

  def healthy(message)
    Result.new('healthy', message, Time.current)
  end

  def unhealthy(message)
    Result.new('unhealthy', message, Time.current)
  end
end
