# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class ApplicantStatusTest < ActiveSupport::TestCase
    test 'submitted application is stage one' do
      app = MembershipApplication.create!(
        email: 'status-submitted@example.com',
        status: 'submitted',
        submitted_at: Time.current
      )

      status = ApplicantStatus.for(app)

      assert_equal :submitted, status.stage
      assert_equal 1, status.step_number
      assert_in_delta 33.0, status.progress_percent, 1.0
      assert_match 'queue for review', status.headline
    end

    test 'acceptance votes move application to review begun' do
      app = MembershipApplication.create!(
        email: 'status-review@example.com',
        status: 'submitted',
        submitted_at: Time.current
      )
      MembershipApplicationAcceptanceVote.create!(
        membership_application: app,
        user: users(:one),
        decision: 'accept'
      )

      status = ApplicantStatus.for(app)

      assert_equal :review_begun, status.stage
      assert_equal 2, status.step_number
      assert_in_delta 67.0, status.progress_percent, 1.0
    end

    test 'approved application is complete' do
      app = MembershipApplication.create!(
        email: 'status-approved@example.com',
        status: 'approved',
        submitted_at: 1.week.ago,
        reviewed_at: Time.current
      )

      status = ApplicantStatus.for(app)

      assert_equal :complete, status.stage
      assert_equal 3, status.step_number
      assert_equal 100, status.progress_percent
      assert status.complete?
    end

    test 'rejected application is complete' do
      app = MembershipApplication.create!(
        email: 'status-rejected@example.com',
        status: 'rejected',
        submitted_at: 1.week.ago,
        reviewed_at: Time.current
      )

      assert_equal :complete, ApplicantStatus.for(app).stage
    end

    test 'under review status is review begun' do
      app = MembershipApplication.create!(
        email: 'status-under-review@example.com',
        status: 'under_review',
        submitted_at: Time.current,
        reviewed_at: Time.current
      )

      status = ApplicantStatus.for(app)

      assert_equal :review_begun, status.stage
      assert_match 'being reviewed', status.headline
    end

    test 'tour feedback moves application to review begun' do
      app = MembershipApplication.create!(
        email: 'status-tour@example.com',
        status: 'submitted',
        submitted_at: Time.current
      )
      MembershipApplicationTourFeedback.create!(
        membership_application: app,
        user: users(:one),
        attitude: 'Positive'
      )

      assert_equal :review_begun, ApplicantStatus.for(app).stage
    end
  end
end
