require 'test_helper'
require Rails.root.join('db/migrate/20260516071100_rewrite_paypal_payment_event_details')

class RewritePaypalPaymentEventDetailsTest < ActiveSupport::TestCase
  test 'rewrites paypal payment event details from payer name' do
    payment = paypal_payments(:sample_payment)
    payment.update!(payer_name: 'Migration Payer', payer_email: 'migration-payer@example.com')
    event = PaymentEvent.create!(
      source: 'paypal',
      event_type: 'payment',
      external_id: payment.paypal_id,
      paypal_payment: payment,
      amount: payment.amount,
      currency: payment.currency,
      occurred_at: payment.transaction_time,
      details: 'PayPal payment from migration-payer@example.com'
    )

    RewritePaypalPaymentEventDetails.new.up

    assert_equal 'PayPal payment from Migration Payer', event.reload.details
  end

  test 'rewrites paypal payment event details from payer email when name is blank' do
    payment = paypal_payments(:sample_payment)
    payment.update!(payer_name: nil, payer_email: 'migration-email@example.com')
    event = PaymentEvent.create!(
      source: 'paypal',
      event_type: 'payment',
      external_id: payment.paypal_id,
      paypal_payment: payment,
      amount: payment.amount,
      currency: payment.currency,
      occurred_at: payment.transaction_time,
      details: 'PayPal payment'
    )

    RewritePaypalPaymentEventDetails.new.up

    assert_equal 'PayPal payment from migration-email@example.com', event.reload.details
  end
end
