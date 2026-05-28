require 'test_helper'

class MailerHealthCheckTest < ActiveSupport::TestCase
  class FakeSmtp
    class << self
      attr_accessor :last, :error, :transaction_error
    end

    attr_accessor :open_timeout, :read_timeout

    def initialize(address, port)
      @address = address
      @port = port
      self.class.last = self
    end

    def enable_tls
      @tls = true
    end

    def enable_starttls
      @starttls = true
    end

    def enable_starttls_auto
      @starttls_auto = true
    end

    def disable_starttls
      @starttls_disabled = true
    end

    def start(domain, username, password, authentication)
      raise self.class.error if self.class.error

      @domain = domain
      @username = username
      @password = password
      @authentication = authentication
      yield self if block_given?
    end

    def mailfrom(from_addr:)
      raise self.class.transaction_error if self.class.transaction_error

      @mail_from = from_addr
    end

    def rcptto(to_addr:)
      raise self.class.transaction_error if self.class.transaction_error

      @rcpt_to = to_addr
    end

    def rset
      @reset = true
    end

    attr_reader :address, :port, :domain, :username, :password, :authentication, :tls, :starttls, :starttls_auto,
                :starttls_disabled, :mail_from, :rcpt_to, :reset
  end

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    Rails.cache.clear
    @original_delivery_method = Rails.configuration.action_mailer.delivery_method
    @original_smtp_settings = Rails.configuration.action_mailer.smtp_settings&.dup
    @original_from = ENV.fetch('EMAIL_FROM_ADDRESS', nil)
    @original_rcpt = ENV.fetch('SMTP_HEALTH_CHECK_RCPT_TO', nil)
    @original_skip = ENV.fetch('SMTP_HEALTH_CHECK_SKIP_TRANSACTION', nil)
    @original_smtp_new = Net::SMTP.method(:new)
    FakeSmtp.error = nil
    FakeSmtp.transaction_error = nil
    FakeSmtp.last = nil
    ENV['EMAIL_FROM_ADDRESS'] = 'noreply@example.test'
    ENV.delete('SMTP_HEALTH_CHECK_RCPT_TO')
    ENV.delete('SMTP_HEALTH_CHECK_SKIP_TRANSACTION')
    Net::SMTP.define_singleton_method(:new) { |address, port| FakeSmtp.new(address, port) }
  end

  teardown do
    Rails.cache.clear
    Rails.cache = @original_cache
    Rails.configuration.action_mailer.delivery_method = @original_delivery_method
    Rails.configuration.action_mailer.smtp_settings = @original_smtp_settings
    if @original_from
      ENV['EMAIL_FROM_ADDRESS'] = @original_from
    else
      ENV.delete('EMAIL_FROM_ADDRESS')
    end
    if @original_rcpt
      ENV['SMTP_HEALTH_CHECK_RCPT_TO'] = @original_rcpt
    else
      ENV.delete('SMTP_HEALTH_CHECK_RCPT_TO')
    end
    if @original_skip
      ENV['SMTP_HEALTH_CHECK_SKIP_TRANSACTION'] = @original_skip
    else
      ENV.delete('SMTP_HEALTH_CHECK_SKIP_TRANSACTION')
    end
    Net::SMTP.define_singleton_method(:new, @original_smtp_new)
  end

  test 'healthy when SMTP connection and authentication succeed' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      port: 587,
      domain: 'members.example.test',
      user_name: 'mailer',
      password: 'secret',
      authentication: :plain,
      enable_starttls_auto: true
    }

    result = MailerHealthCheck.call(force: true)

    assert result.healthy?
    assert_match(/Connected and authenticated/, result.message)
    assert_match(%r{verified MAIL FROM/RCPT TO}, result.message)
    assert_equal 'smtp.example.test', FakeSmtp.last.address
    assert_equal 587, FakeSmtp.last.port
    assert_equal 'members.example.test', FakeSmtp.last.domain
    assert_equal 'mailer', FakeSmtp.last.username
    assert_equal 'secret', FakeSmtp.last.password
    assert_equal :plain, FakeSmtp.last.authentication
    assert_equal true, FakeSmtp.last.starttls_auto
    assert_nil FakeSmtp.last.starttls_disabled
    assert_equal 'noreply@example.test', FakeSmtp.last.mail_from
    assert_equal 'noreply@example.test', FakeSmtp.last.rcpt_to
    assert_equal true, FakeSmtp.last.reset
  end

  test 'healthy for local SMTP relay without TLS' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'localhost',
      port: 25,
      domain: 'members.example.test',
      user_name: 'mailer',
      password: 'secret',
      authentication: :plain,
      enable_starttls_auto: false
    }

    result = MailerHealthCheck.call(force: true)

    assert result.healthy?
    assert_equal 'Connected and authenticated to localhost:25, verified MAIL FROM/RCPT TO', result.message
    assert_equal 'localhost', FakeSmtp.last.address
    assert_equal 25, FakeSmtp.last.port
    assert_equal 'mailer', FakeSmtp.last.username
    assert_equal 'secret', FakeSmtp.last.password
    assert_equal :plain, FakeSmtp.last.authentication
    assert_nil FakeSmtp.last.tls
    assert_nil FakeSmtp.last.starttls
    assert_nil FakeSmtp.last.starttls_auto
    assert_equal true, FakeSmtp.last.starttls_disabled
  end

  test 'unhealthy when SMTP credentials are partially configured' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      user_name: 'mailer'
    }

    result = MailerHealthCheck.call(force: true)

    assert_not result.healthy?
    assert_equal 'SMTP password is missing', result.message
  end

  test 'unhealthy when SMTP authentication fails' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      user_name: 'mailer',
      password: 'bad'
    }
    FakeSmtp.error = Net::SMTPAuthenticationError.new('535 auth failed')

    result = MailerHealthCheck.call(force: true)

    assert_not result.healthy?
    assert_match(/authentication failed/i, result.message)
  end

  test 'unhealthy when SMTP is not configured' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = { address: 'smtp.example.com' }

    result = MailerHealthCheck.call(force: true)

    assert_not result.healthy?
    assert_equal 'SMTP is not configured', result.message
  end

  test 'unhealthy when SMTP rejects the transaction probe' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      user_name: 'mailer',
      password: 'secret'
    }
    FakeSmtp.transaction_error = Net::SMTPFatalError.new('550 relay access denied')

    result = MailerHealthCheck.call(force: true)

    assert_not result.healthy?
    assert_match(/rejected the health check/i, result.message)
    assert_match(/550 relay access denied/, result.message)
  end

  test 'unhealthy when recent delivery failures were recorded' do
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      user_name: 'mailer',
      password: 'secret'
    }
    MailerDeliveryMonitor.record_failure!(RuntimeError.new('smtp down'), source: 'MemberMailer#welcome')

    result = MailerHealthCheck.call(force: true)

    assert_not result.healthy?
    assert_match(/Recent mail delivery failed/, result.message)
    assert_match(/smtp down/, result.message)
  end

  test 'can skip transaction probe when relay rejects synthetic recipients' do
    ENV['SMTP_HEALTH_CHECK_SKIP_TRANSACTION'] = 'true'
    Rails.configuration.action_mailer.delivery_method = :smtp
    Rails.configuration.action_mailer.smtp_settings = {
      address: 'smtp.example.test',
      user_name: 'mailer',
      password: 'secret'
    }

    result = MailerHealthCheck.call(force: true)

    assert result.healthy?
    assert_match(/Connected and authenticated/, result.message)
    assert_no_match(%r{verified MAIL FROM/RCPT TO}, result.message)
    assert_nil FakeSmtp.last.mail_from
  end
end
