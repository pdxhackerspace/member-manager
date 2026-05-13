require 'test_helper'
require Rails.root.join('db/migrate/20260513170000_encrypt_sensitive_database_fields')

class EncryptSensitiveDatabaseFieldsTest < ActiveSupport::TestCase
  test 'backfill encrypts legacy plaintext without losing readable values' do
    user = users(:one)
    payment = PaypalPayment.create!(
      paypal_id: 'LEGACY-PAYPAL-BACKFILL',
      payer_name: 'Legacy Payer',
      payer_email: 'initial@example.com',
      raw_attributes: { 'initial' => true }
    )

    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL.squish)
      UPDATE users
      SET email = 'legacy-user@example.com',
          extra_emails = ARRAY['legacy-extra@example.com'],
          mailing_address = '456 Legacy Ave',
          phone_number = '555-000-1111',
          email_lookup_digest = NULL,
          extra_email_lookup_digests = ARRAY[]::varchar[]
      WHERE id = #{user.id}
    SQL
    connection.execute(<<~SQL.squish)
      UPDATE paypal_payments
      SET payer_email = 'legacy-payer@example.com',
          raw_attributes = '{"payer":{"email":"legacy-payer@example.com"}}'::jsonb,
          payer_email_lookup_digest = NULL
      WHERE id = #{payment.id}
    SQL

    EncryptSensitiveDatabaseFields.new.send(:backfill_encrypted_values)

    user.reload
    payment.reload

    assert_equal 'legacy-user@example.com', user.email
    assert_equal ['legacy-extra@example.com'], user.extra_emails
    assert_equal '456 Legacy Ave', user.mailing_address
    assert_equal '555-000-1111', user.phone_number
    assert_equal user, User.lookup_by_email('LEGACY-USER@example.com')
    assert_equal user, User.by_any_email('legacy-extra@example.com').first
    assert_equal 'legacy-payer@example.com', payment.payer_email
    assert_equal({ 'payer' => { 'email' => 'legacy-payer@example.com' } }, payment.raw_attributes)
    assert_equal payment, PaypalPayment.by_payer_email('legacy-payer@example.com').first

    assert_not_includes raw_user_text(user), 'legacy-user@example.com'
    assert_not_includes raw_user_text(user), 'legacy-extra@example.com'
    assert_not_includes raw_user_text(user), '456 Legacy Ave'
    assert_not_includes raw_payment_text(payment), 'legacy-payer@example.com'
  end

  private

  def raw_user_text(user)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT CONCAT_WS(' ', email, array_to_string(extra_emails, ' '), mailing_address, phone_number)
      FROM users
      WHERE id = #{user.id}
    SQL
  end

  def raw_payment_text(payment)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT CONCAT_WS(' ', payer_email, raw_attributes::text)
      FROM paypal_payments
      WHERE id = #{payment.id}
    SQL
  end
end
