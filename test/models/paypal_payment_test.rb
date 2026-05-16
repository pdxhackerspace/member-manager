require 'test_helper'

class PaypalPaymentTest < ActiveSupport::TestCase
  test 'payment_event_details uses payer name when present' do
    payment = PaypalPayment.new(payer_name: 'Named Supporter', payer_email: 'named@example.com')

    assert_equal 'PayPal payment from Named Supporter', payment.payment_event_details
  end

  test 'payment_event_details falls back to payer email when name is blank' do
    payment = PaypalPayment.new(payer_email: 'private-paypal@example.com')

    assert_equal 'PayPal payment from private-paypal@example.com', payment.payment_event_details
  end
end
