class SeedApplicationVerificationCheckEmailFragment < ActiveRecord::Migration[8.1]
  def up
    TextFragment.ensure_exists!(
      key: 'application_verification_check_email',
      title: 'Application Verification: Check Email',
      content: <<~HTML
        <h2 class="h4 mb-3">Check Your Email</h2>
        <p class="mb-4">
          We've sent a verification link to the email address you provided.
          Please check your inbox and click the link to begin your membership application.
        </p>
      HTML
    )
  end

  def down
    TextFragment.find_by(key: 'application_verification_check_email')&.destroy
  end
end
