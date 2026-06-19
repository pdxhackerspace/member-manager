require 'test_helper'
require 'active_job/test_helper'

class ApplicationVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    MembershipSetting.instance.update!(use_builtin_membership_application: true)
  end

  # ─── Gate Page ───────────────────────────────────────────────────

  test 'gate page renders successfully' do
    get apply_new_path
    assert_response :success
    assert_match 'Membership Application', response.body
    assert_match 'Thank you for your interest in joining', response.body
    assert_match 'attended an open house', response.body
    assert_match 'Code of Conduct', response.body
  end

  test 'gate page renders text fragment content when configured' do
    TextFragment.ensure_exists!(
      key: 'application_verification_gate_intro',
      title: 'Application Verification: Gate Introduction',
      content: '<p>Custom gate intro text for applicants.</p>'
    )

    get apply_new_path

    assert_response :success
    assert_match 'Custom gate intro text for applicants', response.body
    assert_no_match 'Thank you for your interest in joining', response.body
  end

  # ─── Validation Errors ──────────────────────────────────────────

  test 'rejects submission without open house confirmation' do
    post apply_new_path, params: {
      confirmed_code_of_conduct: '1',
      email: 'test@example.com'
    }
    assert_redirected_to apply_new_path
    assert_equal 'You must confirm that you have attended an open house.', flash[:alert]
  end

  test 'rejects submission without code of conduct confirmation' do
    post apply_new_path, params: {
      confirmed_open_house: '1',
      email: 'test@example.com'
    }
    assert_redirected_to apply_new_path
    assert_equal 'You must confirm that you have read and agree with the Code of Conduct.', flash[:alert]
  end

  test 'rejects submission with blank email' do
    post apply_new_path, params: {
      confirmed_open_house: '1',
      confirmed_code_of_conduct: '1',
      email: ''
    }
    assert_redirected_to apply_new_path
    assert_equal 'Please enter a valid email address.', flash[:alert]
  end

  test 'rejects submission with invalid email' do
    post apply_new_path, params: {
      confirmed_open_house: '1',
      confirmed_code_of_conduct: '1',
      email: 'not-an-email'
    }
    assert_redirected_to apply_new_path
    assert_equal 'Please enter a valid email address.', flash[:alert]
  end

  # ─── Successful Submission ──────────────────────────────────────

  test 'creates verification and sends email on valid submission' do
    assert_difference 'ApplicationVerification.count', 1 do
      assert_enqueued_emails 1 do
        post apply_new_path, params: {
          confirmed_open_house: '1',
          confirmed_code_of_conduct: '1',
          email: 'applicant@example.com'
        }
      end
    end

    assert_redirected_to apply_check_email_path
    verification = ApplicationVerification.last
    assert_equal 'applicant@example.com', verification.email
    assert verification.confirmed_open_house?
    assert verification.confirmed_code_of_conduct?
    assert_not verification.email_verified?
  end

  # ─── Check Email Page ──────────────────────────────────────────

  test 'check_email page renders successfully' do
    get apply_check_email_path
    assert_response :success
    assert_match 'Check Your Email', response.body
  end

  test 'check_email page renders text fragment content when configured' do
    TextFragment.ensure_exists!(
      key: 'application_verification_check_email',
      title: 'Application Verification: Check Email',
      content: '<h2 class="h4 mb-3">Custom check-email heading</h2><p class="mb-4">Custom check-email body.</p>'
    )

    get apply_check_email_path

    assert_response :success
    assert_match 'Custom check-email heading', response.body
    assert_match 'Custom check-email body', response.body
    assert_no_match 'Check Your Email', response.body
  end

  # ─── Email Verification ────────────────────────────────────────

  test 'valid token verifies email and redirects to application' do
    verification = ApplicationVerification.create!(
      email: 'test@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )

    get apply_verify_email_path(token: verification.token)

    assert_redirected_to apply_start_path
    verification.reload
    assert verification.email_verified?
    assert_not_nil verification.verified_at
  end

  test 'verify link redirects to status page when application already submitted' do
    verification = ApplicationVerification.create!(
      email: 'status-link@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    MembershipApplication.create!(
      email: 'status-link@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )

    get apply_verify_email_path(token: verification.token)

    assert_redirected_to apply_application_status_path(token: verification.token)
    assert verification.reload.email_verified?
  end

  test 'status link works after verification expires when application was submitted' do
    verification = ApplicationVerification.create!(
      email: 'expired-status@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    verification.update_columns(expires_at: 1.hour.ago, email_verified: true, verified_at: 1.day.ago)
    MembershipApplication.create!(
      email: 'expired-status@example.com',
      status: 'submitted',
      submitted_at: 2.days.ago
    )

    get apply_application_status_path(token: verification.token)

    assert_response :success
    assert_match 'in the queue for review', response.body
    assert_match 'Application submitted', response.body
    assert_match '1/3', response.body
  end

  test 'status page shows timing guidance and overdue apology' do
    travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
      opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
      MembershipApplication.create!(
        email: 'baseline@example.com',
        status: 'approved',
        submitted_at: opened_at,
        reviewed_at: opened_at + 2.days
      )
      TextFragment.ensure_exists!(
        key: MembershipApplications::ApplicantStatusTiming::OVERDUE_APOLOGY_FRAGMENT_KEY,
        title: 'Application Status: Overdue Apology',
        content: '<p>Sorry for the delay from the fragment.</p>'
      )
      verification = ApplicationVerification.create!(
        email: 'timing-status@example.com',
        confirmed_open_house: true,
        confirmed_code_of_conduct: true
      )
      MembershipApplication.create!(
        email: 'timing-status@example.com',
        status: 'submitted',
        submitted_at: 5.days.ago
      )

      get apply_application_status_path(token: verification.token)

      assert_response :success
      assert_match 'submitted', response.body
      assert_match '5 days', response.body
      assert_match 'review typically takes about', response.body
      assert_match '3 days', response.body
      assert_match 'Sorry for the delay from the fragment', response.body
    end
  end

  test 'status page shows capped review estimate without mentioning cap' do
    travel_to Time.zone.local(2026, 6, 19, 12, 0, 0) do
      MembershipSetting.instance.update!(application_review_time_cap_days: 15)
      opened_at = Time.zone.local(2026, 5, 21, 12, 0, 0)
      MembershipApplication.create!(
        email: 'slow-baseline@example.com',
        status: 'approved',
        submitted_at: opened_at,
        reviewed_at: opened_at + 14.days
      )
      verification = ApplicationVerification.create!(
        email: 'slow-status@example.com',
        confirmed_open_house: true,
        confirmed_code_of_conduct: true
      )
      MembershipApplication.create!(
        email: 'slow-status@example.com',
        status: 'submitted',
        submitted_at: 1.day.ago
      )

      get apply_application_status_path(token: verification.token)

      assert_response :success
      assert_match 'review typically takes about', response.body
      assert_match '15 days', response.body
      assert_no_match '18 days', response.body
      assert_no_match '19 days', response.body
    end
  end

  test 'status page shows review begun progress when admin reviews exist' do
    verification = ApplicationVerification.create!(
      email: 'review-status@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    app = MembershipApplication.create!(
      email: 'review-status@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )
    MembershipApplicationAcceptanceVote.create!(
      membership_application: app,
      user: users(:one),
      decision: 'accept'
    )

    get apply_application_status_path(token: verification.token)

    assert_response :success
    assert_match 'being reviewed', response.body
    assert_match 'Review process begun', response.body
    assert_match '2/3', response.body
  end

  test 'status page shows outcome email when application is rejected' do
    verification = ApplicationVerification.create!(
      email: 'rejected-status@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    app = MembershipApplication.create!(
      email: 'rejected-status@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )
    app.reject!(users(:one), notes: 'Not a fit right now')

    get apply_application_status_path(token: verification.token)

    assert_response :success
    assert_match 'Application process complete', response.body
    assert_match '3/3', response.body
    assert_match 'Decision email', response.body
    assert_match 'Not a fit right now', response.body
  end

  test 'invalid token redirects to gate with error' do
    get apply_verify_email_path(token: 'nonexistent')

    assert_redirected_to apply_new_path
    assert_equal 'Invalid verification link.', flash[:alert]
  end

  test 'expired token redirects to gate with error' do
    verification = ApplicationVerification.create!(
      email: 'test@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    verification.update_columns(expires_at: 1.hour.ago)

    get apply_verify_email_path(token: verification.token)

    assert_redirected_to apply_new_path
    assert_equal 'This verification link has expired. Please start over.', flash[:alert]
  end

  # ─── Application Guard ─────────────────────────────────────────

  test 'application start page redirects without verified token' do
    get apply_start_path
    assert_redirected_to apply_new_path
    assert_equal 'Please verify your email address before starting an application.', flash[:alert]
  end

  test 'application start page accessible with verified token' do
    verification = ApplicationVerification.create!(
      email: 'test@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    verification.verify_email!

    get apply_verify_email_path(token: verification.token)
    follow_redirect!

    assert_response :success
  end

  test 'application page redirects without verified token' do
    get apply_page_path(page_number: 1)
    assert_redirected_to apply_new_path
  end

  test 'application submit redirects without verified token' do
    post apply_submit_path
    assert_redirected_to apply_new_path
  end

  # ─── Code of Conduct PDF ────────────────────────────────────

  test 'code_of_conduct_pdf returns 404 when no document exists' do
    get apply_code_of_conduct_pdf_path
    assert_response :not_found
  end

  test 'code_of_conduct_pdf serves PDF when document exists' do
    Document.create!(
      title: 'Code of Conduct',
      file: fixture_file_upload('code-of-conduct.pdf', 'application/pdf')
    )

    get apply_code_of_conduct_pdf_path
    assert_response :success
    assert_equal 'application/pdf', response.media_type
  end

  # ─── Expired Verification ──────────────────────────────────

  test 'gate renders apply fragment when external application flow' do
    MembershipSetting.instance.update!(use_builtin_membership_application: false)
    TextFragment.ensure_exists!(
      key: 'apply_for_membership',
      title: 'Apply for membership',
      content: '<p>External apply content</p>'
    )

    get apply_new_path

    assert_response :success
    assert_match 'External apply content', response.body
    assert_no_match 'Send Verification Email', response.body
  end

  test 'external flow redirects verification post to apply page' do
    MembershipSetting.instance.update!(use_builtin_membership_application: false)

    assert_no_difference 'ApplicationVerification.count' do
      post apply_new_path, params: {
        confirmed_open_house: '1',
        confirmed_code_of_conduct: '1',
        email: 'applicant@example.com'
      }
    end

    assert_redirected_to apply_path
  end

  test 'expired verification blocks application access' do
    verification = ApplicationVerification.create!(
      email: 'test@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    verification.verify_email!

    get apply_verify_email_path(token: verification.token)

    verification.update_columns(expires_at: 1.hour.ago)

    get apply_start_path
    assert_redirected_to apply_new_path
  end

  test 'apply start redirects to applicant status when application already submitted' do
    verification = ApplicationVerification.create!(
      email: 'start-status-redirect@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )

    get apply_verify_email_path(token: verification.token)
    follow_redirect!
    assert_response :success

    MembershipApplication.create!(
      email: 'start-status-redirect@example.com',
      status: 'submitted',
      submitted_at: Time.current
    )

    get apply_start_path

    assert_redirected_to apply_application_status_path(token: verification.token)
  end

  test 'confirmation page links to applicant status when session has verification token' do
    verification = ApplicationVerification.create!(
      email: 'confirmation-status@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    verification.verify_email!

    get apply_verify_email_path(token: verification.token)
    get apply_confirmation_path

    assert_response :success
    assert_select 'a[href=?]', apply_application_status_path(token: verification.token), text: 'View application status'
  end

  test 'status page shows approved outcome email content' do
    verification = ApplicationVerification.create!(
      email: 'approved-status@example.com',
      confirmed_open_house: true,
      confirmed_code_of_conduct: true
    )
    queued_mail = QueuedMail.create!(
      to: verification.email,
      subject: 'Welcome to the space',
      body_html: '<p>You are approved!</p>',
      body_text: 'You are approved!',
      reason: 'Application approved',
      mailer_action: 'application_approved',
      status: 'approved',
      sent_at: Time.current
    )
    MembershipApplication.create!(
      email: verification.email,
      status: 'approved',
      submitted_at: 1.week.ago,
      reviewed_at: Time.current,
      outcome_queued_mail: queued_mail
    )

    get apply_application_status_path(token: verification.token)

    assert_response :success
    assert_match 'Decision email', response.body
    assert_match 'Welcome to the space', response.body
    assert_match 'You are approved!', response.body
  end
end
