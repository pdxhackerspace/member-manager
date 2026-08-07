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
end
