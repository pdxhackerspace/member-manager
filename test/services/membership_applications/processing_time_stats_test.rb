# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class ProcessingTimeStatsTest < ActiveSupport::TestCase
    test 'call averages finalized applications decided since cutoff' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        since = Time.zone.local(2026, 4, 20, 12, 0, 0)
        opened_at = Time.zone.local(2026, 4, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'stats-fast@example.com',
          status: 'approved',
          submitted_at: opened_at,
          reviewed_at: opened_at + 1.day
        )
        MembershipApplication.create!(
          email: 'stats-slow@example.com',
          status: 'rejected',
          submitted_at: opened_at,
          reviewed_at: opened_at + 3.days
        )
        MembershipApplication.create!(
          email: 'stats-open@example.com',
          status: 'submitted',
          submitted_at: opened_at
        )
        MembershipApplication.create!(
          email: 'stats-old@example.com',
          status: 'approved',
          submitted_at: since - 10.days,
          reviewed_at: since - 1.day
        )

        stats = ProcessingTimeStats.call(since: since)

        assert_equal 2, stats[:count]
        assert_in_delta 2.days.to_i, stats[:average_seconds], 1.0
        assert_equal '2 days', stats[:average_label]
      end
    end

    test 'applicant_estimate multiplies average by one point two five' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'estimate-base@example.com',
          status: 'approved',
          submitted_at: opened_at,
          reviewed_at: opened_at + 2.days
        )

        stats = ProcessingTimeStats.applicant_estimate

        assert_equal 1, stats[:count]
        assert_in_delta 2.5.days.to_i, stats[:estimated_seconds], 1.0
        assert_equal '3 days', stats[:estimated_label]
      end
    end

    test 'default window excludes finalized applications older than one month' do
      travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
        recent_opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
        old_opened_at = Time.zone.local(2026, 4, 21, 12, 0, 0)
        MembershipApplication.create!(
          email: 'recent-stats@example.com',
          status: 'approved',
          submitted_at: recent_opened_at,
          reviewed_at: recent_opened_at + 2.days
        )
        MembershipApplication.create!(
          email: 'old-stats@example.com',
          status: 'approved',
          submitted_at: old_opened_at,
          reviewed_at: old_opened_at + 10.days
        )

        stats = ProcessingTimeStats.call

        assert_equal 1, stats[:count]
        assert_equal '2 days', stats[:average_label]
      end
    end

    test 'format_duration handles minutes hours and days' do
      assert_equal 'less than a minute', ProcessingTimeStats.format_duration(30)
      assert_equal '5 minutes', ProcessingTimeStats.format_duration(300)
      assert_equal '2 hours', ProcessingTimeStats.format_duration(7200)
      assert_equal '4 days', ProcessingTimeStats.format_duration(4.days.to_i)
    end
  end
end
