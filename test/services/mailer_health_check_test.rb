require 'test_helper'

class MailerHealthCheckTest < ActiveSupport::TestCase
  class FakeSmtp
    class << self
      attr_accessor :last, :error
    end

    attr_accessor :open_timeout, :read_timeout

    def initialize(address, port)
      @address = address
      @port = port
      self.class.last = self
    end

    def enable_starttls_auto
      @starttls_auto = true
    end

    def start(domain, username, password, authentication)
      raise self.class.error if self.class.error

      @domain = domain
      @username = username
      @password = password
      @authentication = authentication
      yield if block_given?
    end

    attr_reader :address, :port, :domain, :username, :password, :authentication, :starttls_auto
  end

  setup do
    Rails.cache.delete(MailerHealthCheck::CACHE_KEY)
    @original_delivery_method = Rails.configuration.action_mailer.delivery_method
    @original_smtp_settings = Rails.configuration.action_mailer.smtp_settings&.dup
    @original_smtp_new = Net::SMTP.method(:new)
    FakeSmtp.error = nil
    FakeSmtp.last = nil
    Net::SMTP.define_singleton_method(:new) { |address, port| FakeSmtp.new(address, port) }
  end

  teardown do
    Rails.cache.delete(MailerHealthCheck::CACHE_KEY)
    Rails.configuration.action_mailer.delivery_method = @original_delivery_method
    Rails.configuration.action_mailer.smtp_settings = @original_smtp_settings
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
    assert_equal 'smtp.example.test', FakeSmtp.last.address
    assert_equal 587, FakeSmtp.last.port
    assert_equal 'members.example.test', FakeSmtp.last.domain
    assert_equal 'mailer', FakeSmtp.last.username
    assert_equal 'secret', FakeSmtp.last.password
    assert_equal :plain, FakeSmtp.last.authentication
    assert_equal true, FakeSmtp.last.starttls_auto
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
end
