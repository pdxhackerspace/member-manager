# frozen_string_literal: true

require 'test_helper'

class MembershipApplicationsHelperTest < ActionView::TestCase
  test 'membership_application_applicant_status_path returns status url when verification exists' do
    verification = ApplicationVerification.create!(email: 'helper-status@example.com')
    app = MembershipApplication.create!(
      email: 'helper-status@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )

    assert_equal apply_application_status_path(token: verification.token),
                 membership_application_applicant_status_path(app)
  end

  test 'membership_application_applicant_status_path returns nil without verification' do
    app = MembershipApplication.create!(
      email: 'helper-no-verification@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )

    assert_nil membership_application_applicant_status_path(app)
  end
end
