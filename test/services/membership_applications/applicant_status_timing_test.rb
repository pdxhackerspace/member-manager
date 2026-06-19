# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class ApplicantStatusTimingTest < ActiveSupport::TestCase
    test 'shows estimated review time at one point two five times recent average' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'avg-fast@example.com',
          status: 'approved',
          submitted_at: opened_at,
          reviewed_at: opened_at + 2.days
        )
        MembershipApplication.create!(
          email: 'avg-slow@example.com',
          status: 'rejected',
          submitted_at: opened_at,
          reviewed_at: opened_at + 4.days
        )
        app = MembershipApplication.create!(
          email: 'waiting-applicant@example.com',
          status: 'submitted',
          submitted_at: 1.day.ago
        )

        timing = ApplicantStatusTiming.for(app, now: Time.current)

        assert_equal '4 days', timing[:estimate][:estimated_label]
        assert_equal '1 day', timing[:waiting_label]
        assert_not timing[:show_apology]
      end
    end

    test 'shows apology when waiting longer than recent average' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'baseline@example.com',
          status: 'approved',
          submitted_at: opened_at,
          reviewed_at: opened_at + 2.days
        )
        TextFragment.ensure_exists!(
          key: ApplicantStatusTiming::OVERDUE_APOLOGY_FRAGMENT_KEY,
          title: 'Application Status: Overdue Apology',
          content: '<p>Custom overdue apology message.</p>'
        )
        app = MembershipApplication.create!(
          email: 'long-wait@example.com',
          status: 'submitted',
          submitted_at: 5.days.ago
        )

        timing = ApplicantStatusTiming.for(app, now: Time.current)

        assert timing[:show_apology]
        assert_match 'Custom overdue apology message', timing[:apology_content]
      end
    end

    test 'does not show apology for finalized applications' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'baseline@example.com',
          status: 'approved',
          submitted_at: opened_at,
          reviewed_at: opened_at + 2.days
        )
        app = MembershipApplication.create!(
          email: 'already-done@example.com',
          status: 'approved',
          submitted_at: 10.days.ago,
          reviewed_at: Time.current
        )

        timing = ApplicantStatusTiming.for(app, now: Time.current)

        assert_not timing[:show_apology]
      end
    end
  end
end
