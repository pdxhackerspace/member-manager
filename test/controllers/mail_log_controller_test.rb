require 'test_helper'

class MailLogControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_local_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'show displays direct mail message snapshot' do
    entry = MailLogEntry.log_direct_delivery!(
      to: 'applicant@example.com',
      subject: 'Verify your email',
      mailer_class: 'MemberMailer',
      mailer_action: 'application_email_verification',
      body_html: '<p>Use this verification link.</p>',
      body_text: 'Use this verification link.'
    )

    get mail_log_entry_path(entry)

    assert_response :success
    assert_match 'Verify your email', response.body
    assert_match 'Use this verification link.', response.body
  end

  test 'index links log rows to their detail pages' do
    entry = MailLogEntry.log_queued_delivery!(queued_mails(:approved_mail))

    get mail_log_path

    assert_response :success
    assert_select 'a[href=?]', mail_log_entry_path(entry)
  end

  private

  def sign_in_as_local_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: {
        email: account.email,
        password: 'localpassword123'
      }
    }
  end
end
