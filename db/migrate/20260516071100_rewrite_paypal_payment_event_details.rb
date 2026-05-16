class RewritePaypalPaymentEventDetails < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE payment_events
      SET details = CASE
        WHEN NULLIF(paypal_payments.payer_name, '') IS NOT NULL
          THEN 'PayPal payment from ' || paypal_payments.payer_name
        WHEN NULLIF(paypal_payments.payer_email, '') IS NOT NULL
          THEN 'PayPal payment from ' || paypal_payments.payer_email
        ELSE 'PayPal payment'
      END
      FROM paypal_payments
      WHERE payment_events.source = 'paypal'
        AND payment_events.paypal_payment_id = paypal_payments.id
    SQL
  end

  def down
    # Data rewrite only; previous mixed detail strings cannot be recovered reliably.
  end
end
