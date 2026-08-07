require 'test_helper'

module Membership
  class ActiveStatusTest < ActiveSupport::TestCase
    test 'priority: banned beats sponsored' do
      user = build_user(membership_status: 'banned', is_sponsored: true, dues_status: 'current')

      assert_not ActiveStatus.compute(user)
    end

    test 'priority: deceased beats sponsored' do
      user = build_user(membership_status: 'deceased', is_sponsored: true, dues_status: 'current')

      assert_not ActiveStatus.compute(user)
    end

    test 'priority: sponsored beats lapsed dues' do
      user = build_user(membership_status: 'paying', is_sponsored: true, dues_status: 'lapsed')

      assert ActiveStatus.compute(user)
    end

    test 'priority: sponsored beats expired limited access timestamp' do
      user = build_user(membership_status: 'sponsored', dues_due_at: 1.day.ago, dues_status: 'inactive')

      assert ActiveStatus.compute(user)
    end

    test 'priority: is_sponsored flag stays active with expired limited access timestamp' do
      user = build_user(
        membership_status: 'paying',
        is_sponsored: true,
        dues_due_at: 1.hour.ago,
        dues_status: 'current'
      )

      assert ActiveStatus.compute(user)
    end

    test 'priority: payment_type sponsored stays active with lapsed dues' do
      user = build_user(membership_status: 'unknown', payment_type: 'sponsored', dues_status: 'lapsed')

      assert ActiveStatus.compute(user)
    end

    test 'priority: lapsed paying member without sponsorship is inactive' do
      user = build_user(membership_status: 'paying', dues_status: 'lapsed')

      assert_not ActiveStatus.compute(user)
    end

    test 'priority: current paying member is active' do
      user = build_user(membership_status: 'paying', dues_status: 'current')

      assert ActiveStatus.compute(user)
    end

    test 'guest with expired limited access is inactive' do
      user = build_user(membership_status: 'guest', dues_due_at: 1.day.ago)

      assert_not ActiveStatus.compute(user)
    end

    test 'guest without end date is active' do
      user = build_user(membership_status: 'guest', dues_status: 'unknown')

      assert ActiveStatus.compute(user)
    end

    test 'apply_to sets deceased payment type inactive' do
      user = build_user(membership_status: 'deceased', payment_type: 'paypal')
      user.save!

      ActiveStatus.apply_to(user)

      assert_not user.active
      assert_equal 'inactive', user.payment_type
    end

    test 'reconcile activates sponsored member marked inactive' do
      user = build_user(membership_status: 'sponsored', dues_status: 'lapsed')
      user.save!
      user.update_columns(active: false)

      assert ActiveStatus.reconcile!(user)
      assert user.reload.active
    end

    test 'assign_and_save recomputes active from membership inputs' do
      user = build_user(membership_status: 'paying', dues_status: 'lapsed')
      user.save!

      ActiveStatus.assign_and_save!(user, dues_status: 'current')

      assert user.reload.active
    end

    test 'service account active flag is not recomputed' do
      user = User.create!(
        authentik_id: 'service-active-status',
        full_name: 'Service Account',
        service_account: true,
        active: false,
        membership_status: 'unknown',
        dues_status: 'unknown',
        payment_type: 'unknown'
      )

      assert_not ActiveStatus.reconcile!(user)
      assert_not user.reload.active
    end

    test 'restore_sponsored_membership fixes is_sponsored member after recalculate reset' do
      user = User.create!(
        authentik_id: 'recalc-sponsored-flag',
        full_name: 'Sponsored Flag Member',
        is_sponsored: true,
        membership_status: 'paying',
        dues_status: 'current',
        payment_type: 'paypal'
      )
      ActiveStatus.assign_and_save!(
        user,
        membership_status: 'unknown',
        dues_status: 'unknown',
        membership_plan_id: nil
      )

      assert ActiveStatus.recalculate_sponsored_candidate?(user.reload)

      ActiveStatus.restore_sponsored_membership!(user)

      user.reload
      assert_equal 'sponsored', user.membership_status
      assert_equal 'current', user.dues_status
      assert_equal 'sponsored', user.payment_type
      assert user.active?
    end

    test 'restore_sponsored_membership fixes payment_type sponsored after recalculate reset' do
      user = User.create!(
        authentik_id: 'recalc-payment-sponsored',
        full_name: 'Payment Sponsored Member',
        membership_status: 'paying',
        dues_status: 'current',
        payment_type: 'sponsored'
      )
      ActiveStatus.assign_and_save!(
        user,
        membership_status: 'unknown',
        dues_status: 'unknown',
        membership_plan_id: nil
      )

      assert ActiveStatus.recalculate_sponsored_candidate?(user.reload)

      ActiveStatus.restore_sponsored_membership!(user)

      user.reload
      assert_equal 'sponsored', user.membership_status
      assert_equal 'current', user.dues_status
      assert user.active?
    end

    test 'recalculate_sponsored_candidate rejects banned members even with is_sponsored' do
      user = build_user(membership_status: 'banned', is_sponsored: true, active: false)

      assert_not ActiveStatus.recalculate_sponsored_candidate?(user)
    end

    test 'recalculate_sponsored_candidate rejects deceased members even with payment_type sponsored' do
      user = build_user(membership_status: 'deceased', payment_type: 'sponsored', active: false)

      assert_not ActiveStatus.recalculate_sponsored_candidate?(user)
    end

    private

    def build_user(**attrs)
      defaults = {
        authentik_id: SecureRandom.hex(4),
        full_name: 'Active Status Test',
        membership_status: 'unknown',
        dues_status: 'unknown',
        payment_type: 'unknown'
      }
      User.new(defaults.merge(attrs))
    end
  end
end
