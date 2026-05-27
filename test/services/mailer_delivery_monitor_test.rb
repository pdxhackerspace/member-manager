# frozen_string_literal: true

require 'test_helper'

class MailerDeliveryMonitorTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
    Rails.cache = @original_cache
  end

  test 'record_failure! invalidates cached health check and stores recent failure' do
    Rails.cache.write(MailerHealthCheck::CACHE_KEY, 'cached healthy result', expires_in: 5.minutes)

    MailerDeliveryMonitor.record_failure!(RuntimeError.new('smtp down'), source: 'MemberMailer#welcome')

    assert_nil Rails.cache.read(MailerHealthCheck::CACHE_KEY)
    assert_equal 1, MailerDeliveryMonitor.recent_failures.size
    assert_equal 'RuntimeError', MailerDeliveryMonitor.recent_failures.last['error_class']
    assert_equal 'MemberMailer#welcome', MailerDeliveryMonitor.recent_failures.last['source']
  end

  test 'unhealthy_result summarizes recent failures' do
    travel_to Time.zone.parse('2026-05-27 12:00:00') do
      MailerDeliveryMonitor.record_failure!(Net::SMTPFatalError.new('550 relay denied'))
      MailerDeliveryMonitor.record_failure!(Net::OpenTimeout.new('execution expired'))

      result = MailerDeliveryMonitor.unhealthy_result

      assert_not result.healthy?
      assert_match(/2 mail deliveries failed/, result.message)
      assert_match(/Net::OpenTimeout/, result.message)
    end
  end

  test 'unhealthy_result ignores failures outside the monitoring window' do
    travel_to Time.zone.parse('2026-05-27 12:00:00') do
      MailerDeliveryMonitor.record_failure!(RuntimeError.new('old failure'))
    end

    travel_to Time.zone.parse('2026-05-27 12:20:00') do
      assert_nil MailerDeliveryMonitor.unhealthy_result
    end
  end
end
