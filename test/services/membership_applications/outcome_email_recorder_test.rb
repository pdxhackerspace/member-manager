# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class OutcomeEmailRecorderTest < ActiveSupport::TestCase
    test 'assign! links queued mail to application' do
      app = MembershipApplication.create!(
        email: 'recorder-queued@example.com',
        status: 'rejected',
        submitted_at: Time.current,
        reviewed_at: Time.current
      )
      queued_mail = QueuedMail.create!(
        to: app.email,
        subject: 'Decision',
        body_html: '<p>Rejected</p>',
        body_text: 'Rejected',
        reason: 'Application rejected',
        mailer_action: 'application_rejected',
        status: 'pending'
      )

      OutcomeEmailRecorder.assign!(app, queued_mail)

      assert_equal queued_mail.id, app.reload.outcome_queued_mail_id
    end

    test 'assign! stores immediate delivery snapshot' do
      app = MembershipApplication.create!(
        email: 'recorder-immediate@example.com',
        status: 'approved',
        submitted_at: Time.current,
        reviewed_at: Time.current
      )
      delivery = QueuedMail::ImmediateDelivery.new(
        to: app.email,
        subject: 'Welcome',
        body_html: '<p>Approved</p>',
        body_text: 'Approved',
        email_template: nil
      )

      OutcomeEmailRecorder.assign!(app, delivery)

      app.reload
      assert_nil app.outcome_queued_mail_id
      assert_equal 'Welcome', app.outcome_email_subject
      assert_includes app.outcome_email_body_html, 'Approved'
    end

    test 'for_display prefers queued mail over snapshot fields' do
      queued_mail = QueuedMail.create!(
        to: 'display@example.com',
        subject: 'Queued subject',
        body_html: '<p>Queued body</p>',
        body_text: 'Queued body',
        reason: 'Application rejected',
        mailer_action: 'application_rejected',
        status: 'pending'
      )
      app = MembershipApplication.create!(
        email: 'display@example.com',
        status: 'rejected',
        submitted_at: Time.current,
        reviewed_at: Time.current,
        outcome_queued_mail: queued_mail,
        outcome_email_subject: 'Snapshot subject',
        outcome_email_body_html: '<p>Snapshot body</p>'
      )

      display = OutcomeEmailRecorder.for_display(app)

      assert_equal 'Queued subject', display[:subject]
      assert_includes display[:body_html], 'Queued body'
    end

    test 'for_display falls back to snapshot fields' do
      app = MembershipApplication.create!(
        email: 'display-snapshot@example.com',
        status: 'approved',
        submitted_at: Time.current,
        reviewed_at: Time.current,
        outcome_email_subject: 'Snapshot subject',
        outcome_email_body_html: '<p>Snapshot body</p>'
      )

      display = OutcomeEmailRecorder.for_display(app)

      assert_equal 'Snapshot subject', display[:subject]
      assert_includes display[:body_html], 'Snapshot body'
    end
  end
end
