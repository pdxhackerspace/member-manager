require 'test_helper'

class MailDeliveryLogInterceptorTest < ActiveSupport::TestCase
  test 'direct delivery interceptor preserves message bodies when used' do
    mail = Mail.new do
      to 'applicant@example.com'
      subject 'Verify your email'
      text_part { body 'Text verification link: https://example.com/apply/verify' }
      html_part { body '<p>HTML verification link: https://example.com/apply/verify</p>' }
    end
    mail['X-MemberManager-Mailer'] = 'MemberMailer'
    mail['X-MemberManager-Action'] = 'application_email_verification'

    assert_difference 'MailLogEntry.count', 1 do
      MailDeliveryLogInterceptor.delivering_email(mail)
    end

    entry = MailLogEntry.order(:created_at).last
    assert_equal 'applicant@example.com', entry.delivery_to
    assert_equal 'MemberMailer', entry.delivery_mailer
    assert_equal 'application_email_verification', entry.delivery_action
    assert_includes entry.message_body_html, 'https://example.com/apply/verify'
    assert_includes entry.message_body_text, 'https://example.com/apply/verify'
  end
end
