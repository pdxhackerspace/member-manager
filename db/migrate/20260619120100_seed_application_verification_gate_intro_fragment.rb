class SeedApplicationVerificationGateIntroFragment < ActiveRecord::Migration[8.1]
  def up
    TextFragment.ensure_exists!(
      key: 'application_verification_gate_intro',
      title: 'Application Verification: Gate Introduction',
      content: <<~HTML
        <p>
          Thank you for your interest in joining! Before you begin your application, please
          confirm the following and provide your email address.
        </p>
      HTML
    )
  end

  def down
    TextFragment.find_by(key: 'application_verification_gate_intro')&.destroy
  end
end
