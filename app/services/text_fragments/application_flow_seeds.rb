# frozen_string_literal: true

module TextFragments
  module ApplicationFlowSeeds
    module_function

    def seed!
      seed_check_email!
      seed_gate_intro!
      seed_overdue_apology!
    end

    def seed_check_email!
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

    def seed_gate_intro!
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

    def seed_overdue_apology!
      TextFragment.ensure_exists!(
        key: 'application_status_overdue_apology',
        title: 'Application Status: Overdue Apology',
        content: <<~HTML
          <p>
            We're sorry your application is taking longer than usual. PDX Hackerspace is run entirely
            by volunteers, and sometimes review can take longer than we'd like. Thank you for your patience
            while our team catches up.
          </p>
        HTML
      )
    end
  end
end
