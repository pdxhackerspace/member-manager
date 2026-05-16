require 'test_helper'

class PaymentEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_local_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'index shows paypal payment details with payer name' do
    payment = paypal_payments(:sample_payment)
    PaymentEvent.create!(
      source: 'paypal',
      event_type: 'payment',
      external_id: payment.paypal_id,
      paypal_payment: payment,
      user: payment.user,
      amount: payment.amount,
      currency: payment.currency,
      occurred_at: Time.current,
      details: payment.payment_event_details
    )

    get payment_events_path(event_type: 'payment')

    assert_response :success
    assert_select 'td', text: /PayPal payment from Sample Donor/
  end

  private

  def sign_in_as_local_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: {
        email: account.email,
        password: 'localpassword123'
      }
    }
  end
end
