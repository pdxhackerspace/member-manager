require 'test_helper'

class MembershipRecalculateStatusTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
    @task = Rake::Task['membership:recalculate_status']
    @task.reenable
  end

  test 'recalculate_status restores is_sponsored members after the blanket reset' do
    user = User.create!(
      authentik_id: 'recalc-task-sponsored',
      full_name: 'Recalc Sponsored',
      is_sponsored: true,
      membership_status: 'paying',
      dues_status: 'current',
      payment_type: 'paypal'
    )

    capture_io { @task.invoke }

    user.reload
    assert_equal 'sponsored', user.membership_status
    assert_equal 'current', user.dues_status
    assert_equal 'sponsored', user.payment_type
    assert user.active?
  end

  test 'recalculate_status leaves banned sponsored members inactive' do
    user = User.create!(
      authentik_id: 'recalc-banned-sponsored',
      full_name: 'Banned Sponsored',
      membership_status: 'banned',
      is_sponsored: true,
      dues_status: 'current',
      payment_type: 'sponsored',
      active: false
    )

    capture_io { @task.invoke }

    user.reload
    assert_equal 'banned', user.membership_status
    assert_not user.active?
  end

  test 'recalculate_status leaves deceased sponsored members inactive' do
    user = User.create!(
      authentik_id: 'recalc-deceased-sponsored',
      full_name: 'Deceased Sponsored',
      membership_status: 'deceased',
      is_sponsored: true,
      payment_type: 'sponsored',
      dues_status: 'current',
      active: false
    )

    capture_io { @task.invoke }

    user.reload
    assert_equal 'deceased', user.membership_status
    assert_not user.active?
  end
end
