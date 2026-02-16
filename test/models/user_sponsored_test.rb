require 'test_helper'

class UserSponsoredTest < ActiveSupport::TestCase
  # ─── Scope ─────────────────────────────────────────────────────────

  test 'is_sponsored scope returns only sponsored users' do
    sponsored = create_user(is_sponsored: true)
    regular = create_user(is_sponsored: false)

    assert_includes User.is_sponsored, sponsored
    assert_not_includes User.is_sponsored, regular
  end

  test 'is_sponsored defaults to false' do
    user = User.new(authentik_id: 'sp-default', full_name: 'Default Test', payment_type: 'unknown')
    assert_not user.is_sponsored?
  end

  # ─── compute_active_status ─────────────────────────────────────────

  test 'sponsored member is always active regardless of dues status' do
    user = create_user(is_sponsored: true, membership_status: 'unknown', dues_status: 'unknown')
    assert user.active?, 'sponsored member should always be active'
  end

  test 'sponsored member stays active even with lapsed dues' do
    user = create_user(is_sponsored: true, membership_status: 'paying', dues_status: 'lapsed')
    assert user.active?, 'sponsored member should stay active even with lapsed dues'
  end

  test 'sponsored member stays active even with inactive dues' do
    user = create_user(is_sponsored: true, membership_status: 'unknown', dues_status: 'inactive')
    assert user.active?, 'sponsored member should stay active even with inactive dues'
  end

  test 'non-sponsored member with unknown status and unknown dues is inactive' do
    user = create_user(is_sponsored: false, membership_status: 'unknown', dues_status: 'unknown')
    assert_not user.active?, 'non-sponsored member with unknown status should be inactive'
  end

  test 'removing sponsored flag re-evaluates active status' do
    user = create_user(is_sponsored: true, membership_status: 'unknown', dues_status: 'unknown')
    assert user.active?

    user.update!(is_sponsored: false)
    assert_not user.active?, 'removing sponsored should re-evaluate active status'
  end

  test 'sponsored member does not get payment_type set to inactive when deceased' do
    user = create_user(is_sponsored: true, membership_status: 'deceased', payment_type: 'paypal')
    user.save!
    assert_equal 'paypal', user.payment_type
  end

  # ─── Journal entry for sponsorship ─────────────────────────────────

  test 'manually marking as sponsored creates a journal entry' do
    user = create_user(is_sponsored: false)
    initial_count = user.journals.count

    user.update!(is_sponsored: true)

    assert_operator user.journals.count, :>, initial_count,
                    'Manual sponsorship should create a journal entry'
  end

  test 'removing sponsorship creates a journal entry' do
    user = create_user(is_sponsored: true)
    initial_count = user.journals.count

    user.update!(is_sponsored: false)

    assert_operator user.journals.count, :>, initial_count,
                    'Removing sponsorship should create a journal entry'
  end

  private

  def create_user(attrs = {})
    defaults = {
      authentik_id: "sponsored-test-#{SecureRandom.hex(4)}",
      full_name: "Sponsored Test #{SecureRandom.hex(4)}",
      payment_type: attrs[:payment_type] || 'unknown',
      membership_status: attrs[:membership_status] || 'unknown',
      dues_status: attrs[:dues_status] || 'unknown',
      is_sponsored: false
    }
    User.create!(defaults.merge(attrs))
  end
end
