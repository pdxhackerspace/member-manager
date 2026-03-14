require 'test_helper'

class ApplicationVerificationTest < ActiveSupport::TestCase
  test 'generates a token on create' do
    verification = ApplicationVerification.create!(email: 'test@example.com')

    assert verification.token.present?
    assert_equal 32, verification.token.length
  end

  test 'sets expiry on create from membership settings' do
    verification = ApplicationVerification.create!(email: 'test@example.com')

    expected = MembershipSetting.application_verification_expiry_hours.hours.from_now
    assert_in_delta expected, verification.expires_at, 5.seconds
  end

  test 'validates email presence' do
    verification = ApplicationVerification.new(email: '')

    assert_not verification.valid?
    assert_includes verification.errors[:email], "can't be blank"
  end

  test 'validates email format' do
    verification = ApplicationVerification.new(email: 'not-an-email')

    assert_not verification.valid?
    assert verification.errors[:email].any?
  end

  test 'validates token uniqueness' do
    existing = ApplicationVerification.create!(email: 'a@example.com')
    duplicate = ApplicationVerification.new(email: 'b@example.com', token: existing.token)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:token], 'has already been taken'
  end

  test 'expired? returns true when past expires_at' do
    verification = ApplicationVerification.create!(email: 'test@example.com')
    verification.update_columns(expires_at: 1.hour.ago)

    assert verification.expired?
  end

  test 'expired? returns false when before expires_at' do
    verification = ApplicationVerification.create!(email: 'test@example.com')

    assert_not verification.expired?
  end

  test 'verified? requires email_verified and not expired' do
    verification = ApplicationVerification.create!(email: 'test@example.com')

    assert_not verification.verified?

    verification.verify_email!

    assert verification.verified?
  end

  test 'verified? returns false when expired even if email_verified' do
    verification = ApplicationVerification.create!(email: 'test@example.com')
    verification.verify_email!
    verification.update_columns(expires_at: 1.hour.ago)

    assert_not verification.verified?
  end

  test 'verify_email! sets email_verified and verified_at' do
    verification = ApplicationVerification.create!(email: 'test@example.com')

    assert_not verification.email_verified?
    assert_nil verification.verified_at

    verification.verify_email!

    assert verification.email_verified?
    assert_not_nil verification.verified_at
  end

  test 'active scope returns only verified and unexpired records' do
    expired = ApplicationVerification.create!(email: 'a@example.com')
    expired.verify_email!
    expired.update_columns(expires_at: 1.hour.ago)

    unverified = ApplicationVerification.create!(email: 'b@example.com')

    active = ApplicationVerification.create!(email: 'c@example.com')
    active.verify_email!

    results = ApplicationVerification.active
    assert_includes results, active
    assert_not_includes results, expired
    assert_not_includes results, unverified
  end
end
