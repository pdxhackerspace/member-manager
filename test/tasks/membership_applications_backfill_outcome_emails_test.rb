# frozen_string_literal: true

require 'test_helper'

class MembershipApplicationsBackfillOutcomeEmailsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
    @task = Rake::Task['membership_applications:backfill_outcome_emails']
    @task.reenable
  end

  test 'links sent queued rejection mail to finalized application' do
    reviewed_at = Time.zone.local(2026, 5, 1, 12, 0, 0)
    app = MembershipApplication.create!(
      email: 'backfill-reject@example.com',
      status: 'rejected',
      submitted_at: reviewed_at - 2.days,
      reviewed_at: reviewed_at
    )
    queued_mail = QueuedMail.create!(
      to: app.email,
      subject: 'Application update',
      body_html: '<p>We are unable to approve your application.</p>',
      body_text: 'We are unable to approve your application.',
      reason: 'Application rejected',
      mailer_action: 'application_rejected',
      status: 'approved',
      sent_at: reviewed_at + 5.minutes
    )

    @task.invoke

    assert_equal queued_mail.id, app.reload.outcome_queued_mail_id
  end

  test 'links direct mail log snapshot when no queued mail exists' do
    reviewed_at = Time.zone.local(2026, 5, 2, 12, 0, 0)
    app = MembershipApplication.create!(
      email: 'backfill-direct@example.com',
      status: 'approved',
      submitted_at: reviewed_at - 1.day,
      reviewed_at: reviewed_at
    )
    MailLogEntry.log_direct_delivery!(
      to: app.email,
      subject: 'Welcome aboard',
      mailer_class: 'MemberMailer',
      mailer_action: 'application_approved',
      body_html: '<p>Your application was approved.</p>'
    )

    @task.invoke

    app.reload
    assert_nil app.outcome_queued_mail_id
    assert_equal 'Welcome aboard', app.outcome_email_subject
    assert_includes app.outcome_email_body_html, 'approved'
  end

  test 'skips applications that already have outcome links' do
    existing_mail = QueuedMail.create!(
      to: 'already-linked@example.com',
      subject: 'Existing',
      body_html: '<p>Existing</p>',
      body_text: 'Existing',
      reason: 'Application rejected',
      mailer_action: 'application_rejected',
      status: 'approved',
      sent_at: Time.current
    )
    app = MembershipApplication.create!(
      email: 'already-linked@example.com',
      status: 'rejected',
      submitted_at: 2.days.ago,
      reviewed_at: 1.day.ago,
      outcome_queued_mail: existing_mail
    )
    duplicate_mail = QueuedMail.create!(
      to: app.email,
      subject: 'Duplicate',
      body_html: '<p>Duplicate</p>',
      body_text: 'Duplicate',
      reason: 'Application rejected',
      mailer_action: 'application_rejected',
      status: 'approved',
      sent_at: Time.current
    )

    @task.invoke

    assert_equal existing_mail.id, app.reload.outcome_queued_mail_id
    assert_not_equal duplicate_mail.id, app.outcome_queued_mail_id
  end
end
