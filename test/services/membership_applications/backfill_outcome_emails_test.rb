# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class BackfillOutcomeEmailsTest < ActiveSupport::TestCase
    test 'prefers queued mail sent closest to reviewed_at' do
      reviewed_at = Time.zone.local(2026, 5, 10, 12, 0, 0)
      app = MembershipApplication.create!(
        email: 'pick-closest@example.com',
        status: 'rejected',
        submitted_at: reviewed_at - 1.day,
        reviewed_at: reviewed_at
      )
      older = QueuedMail.create!(
        to: app.email,
        subject: 'Older rejection',
        body_html: '<p>Older</p>',
        body_text: 'Older',
        reason: 'Application rejected',
        mailer_action: 'application_rejected',
        status: 'approved',
        sent_at: reviewed_at - 2.days
      )
      match = QueuedMail.create!(
        to: app.email,
        subject: 'Matching rejection',
        body_html: '<p>Match</p>',
        body_text: 'Match',
        reason: 'Application rejected',
        mailer_action: 'application_rejected',
        status: 'approved',
        sent_at: reviewed_at + 10.minutes
      )

      result = BackfillOutcomeEmails.call

      assert_equal 1, result.linked_queued_mail
      assert_equal match.id, app.reload.outcome_queued_mail_id
      assert_not_equal older.id, app.outcome_queued_mail_id
    end
  end
end
