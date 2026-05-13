# frozen_string_literal: true

require 'test_helper'

class MailLogEntryTest < ActiveSupport::TestCase
  test 'log_direct_delivery! creates a sent entry without queued mail' do
    entry = MailLogEntry.log_direct_delivery!(
      to: 'admin@example.com',
      subject: 'Hello',
      mailer_class: 'MemberMailer',
      mailer_action: 'admin_new_application',
      body_html: '<p>Hello</p>',
      body_text: 'Hello'
    )

    assert_nil entry.queued_mail_id
    assert_equal 'sent', entry.event
    assert_equal 'admin@example.com', entry.delivery_to
    assert_equal 'Hello', entry.delivery_subject
    assert_equal 'MemberMailer', entry.delivery_mailer
    assert_equal 'admin_new_application', entry.delivery_action
    assert_equal '<p>Hello</p>', entry.message_body_html
    assert_equal 'Hello', entry.message_body_text
  end

  test 'log_direct_delivery! can create a failed direct delivery entry' do
    entry = MailLogEntry.log_direct_delivery!(
      to: 'applicant@example.com',
      subject: 'Verify your email',
      mailer_class: 'MemberMailer',
      mailer_action: 'application_email_verification',
      event: 'send_failed',
      details: 'Net::SMTPFatalError: down'
    )

    assert_equal 'send_failed', entry.event
    assert_equal 'Net::SMTPFatalError: down', entry.details
  end

  test 'log_queued_delivery! stores a snapshot of the sent queued message' do
    queued_mail = queued_mails(:approved_mail)

    entry = MailLogEntry.log_queued_delivery!(queued_mail)

    assert_equal 'sent', entry.event
    assert_equal queued_mail, entry.queued_mail
    assert_equal queued_mail.to, entry.delivery_to
    assert_equal queued_mail.subject, entry.delivery_subject
    assert_equal queued_mail.body_html, entry.message_body_html
    assert_equal queued_mail.body_text, entry.message_body_text
  end

  test 'log! stores queued message snapshot for lifecycle events' do
    queued_mail = queued_mails(:pending_mail)
    original_html = queued_mail.body_html
    original_text = queued_mail.body_text

    entry = MailLogEntry.log!(queued_mail, 'created', details: 'Queued message')

    queued_mail.update!(
      subject: 'Edited later',
      body_html: '<p>Edited later</p>',
      body_text: 'Edited later'
    )

    assert_equal queued_mail.to, entry.delivery_to
    assert_equal 'Test Org: Application Received', entry.delivery_subject
    assert_equal 'QueuedMailMailer', entry.delivery_mailer
    assert_equal queued_mail.mailer_action, entry.delivery_action
    assert_equal original_html, entry.reload.message_body_html
    assert_equal original_text, entry.message_body_text
  end

  test 'log_once! stores queued message snapshot for failed delivery' do
    queued_mail = queued_mails(:pending_mail)
    queued_mail.update!(status: 'approved')

    MailLogEntry.log_once!(queued_mail, 'send_failed', details: 'Net::SMTPFatalError: down')
    entry = queued_mail.mail_log_entries.where(event: 'send_failed').last

    assert_equal queued_mail.to, entry.delivery_to
    assert_equal queued_mail.subject, entry.delivery_subject
    assert_equal queued_mail.body_html, entry.message_body_html
    assert_equal queued_mail.body_text, entry.message_body_text
  end

  test 'log_direct_delivery! requires to and subject' do
    assert_raises(ActiveRecord::RecordInvalid) do
      MailLogEntry.log_direct_delivery!(
        to: '',
        subject: 'Subj',
        mailer_class: 'X',
        mailer_action: 'y'
      )
    end
  end
end
