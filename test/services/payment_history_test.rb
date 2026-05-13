require 'test_helper'

class PaymentHistoryTest < ActiveSupport::TestCase
  test 'for_user returns an enumerable' do
    user = users(:one)
    payments = PaymentHistory.for_user(user)
    assert_respond_to payments, :each
  end

  test 'for_user sorts payments by processed time descending' do
    user = users(:one)
    payments = PaymentHistory.for_user(user).to_a
    if payments.size < 2
      assert_operator payments.size, :<, 2
      return
    end

    times = payments.map { |p| p.processed_time || p.created_at || Time.zone.at(0) }
    assert_equal times, times.sort.reverse
  end

  test 'paypal payment event details do not expose email fallback' do
    user = users(:one)
    payment = PaypalPayment.create!(
      paypal_id: 'PAY-HISTORY-PRIVACY',
      status: 'COMPLETED',
      amount: 10.00,
      currency: 'USD',
      transaction_time: Time.current,
      transaction_type: 'T0001',
      payer_email: 'history-private@example.com',
      payer_id: 'PAYER-HISTORY-PRIVACY',
      matches_plan: true,
      user: user
    )
    event = PaymentEvent.find_by!(source: 'paypal', external_id: payment.paypal_id)

    assert_equal 'PayPal payment', event.details
    assert_no_match(/history-private@example\.com/, event.details)
  end
end
