# frozen_string_literal: true

require 'test_helper'

class MemberMailerTest < ActionMailer::TestCase
  class FailingDelivery
    def initialize(_settings = {}); end

    def deliver!(_mail)
      raise 'smtp down'
    end
  end

  test 'admin_new_application includes application URL in body when provided' do
    EmailTemplate.where(key: 'admin_new_application').update_all(enabled: false)

    applicant = users(:one)
    url = 'https://www.example.com/membership_applications/4242'

    email = nil
    assert_difference 'MailLogEntry.count', 1 do
      email = MemberMailer.admin_new_application(applicant, 'ops@example.com', application_url: url).deliver_now
    end

    entry = MailLogEntry.order(:created_at).last
    assert_nil entry.queued_mail_id
    assert_equal 'ops@example.com', entry.delivery_to
    assert entry.delivery_subject.present?
    assert_includes entry.delivery_body_html, url

    assert_includes email.html_part.body.to_s, url
    text = email.text_part ? email.text_part.body.to_s : email.body.to_s
    assert_includes text, url
  end

  test 'application email verification logs failed delivery instead of sent when delivery raises' do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    Rails.cache.clear
    ActionMailer::Base.add_delivery_method :member_manager_failure, FailingDelivery
    original_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :member_manager_failure

    sent_verification_mail_count = lambda {
      MailLogEntry.where(event: 'sent', delivery_action: 'application_email_verification').count
    }
    failed_verification_mail_count = lambda {
      MailLogEntry.where(event: 'send_failed', delivery_action: 'application_email_verification').count
    }

    assert_no_difference sent_verification_mail_count do
      assert_difference failed_verification_mail_count, 1 do
        assert_raises RuntimeError do
          MemberMailer.application_email_verification(
            'applicant@example.com',
            verification_url: 'https://example.com/verify',
            expires_in: '24 hours'
          ).deliver_now
        end
      end
    end

    entry = MailLogEntry.where(event: 'send_failed', delivery_action: 'application_email_verification').last
    assert_equal 'applicant@example.com', entry.delivery_to
    assert_match(/smtp down/, entry.details)
    assert_includes entry.delivery_body_html, 'https://example.com/verify'
    assert_equal 1, MailerDeliveryMonitor.recent_failures.size
    assert_match(/smtp down/, MailerDeliveryMonitor.recent_failures.last['message'])
  ensure
    Rails.cache = original_cache if defined?(original_cache)
    ActionMailer::Base.delivery_method = original_delivery_method if defined?(original_delivery_method)
  end
end
