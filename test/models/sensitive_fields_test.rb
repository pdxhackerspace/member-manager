require 'test_helper'

class SensitiveFieldsTest < ActiveSupport::TestCase
  test 'user contact fields are encrypted while exact email lookup still works' do
    user = User.create!(
      full_name: 'Encrypted User',
      username: 'encrypted-user',
      email: 'Encrypted.User@Example.com',
      extra_emails: ['Alt.User@Example.com'],
      mailing_address: "123 Secret St\nPortland, OR",
      phone_number: '555-123-4567',
      active: true
    )

    user_row = raw_row('users', user.id)

    assert_equal 'Encrypted.User@Example.com', user.email
    assert_equal ['Alt.User@Example.com'], user.extra_emails
    assert_equal "123 Secret St\nPortland, OR", user.mailing_address
    assert_equal '555-123-4567', user.phone_number
    assert_no_plaintext user_row['email'], 'encrypted.user@example.com'
    assert_no_plaintext user_row['extra_emails'], 'Alt.User@Example.com'
    assert_no_plaintext user_row['mailing_address'], '123 Secret St'
    assert_no_plaintext user_row['phone_number'], '555-123-4567'
    assert_equal user, User.lookup_by_email('ENCRYPTED.USER@example.com')
    assert_equal user, User.by_any_email('alt.user@example.com').first
  end

  test 'integration raw attributes and service keys are encrypted at rest' do
    payment = PaypalPayment.create!(
      paypal_id: 'PAY-SENSITIVE-FIELDS',
      payer_email: 'payer-sensitive@example.com',
      payer_name: 'Sensitive Payer',
      raw_attributes: { 'payer_info' => { 'email_address' => 'payer-sensitive@example.com' } }
    )
    reader = RfidReader.create!(name: 'Encrypted Reader', key: 'a' * 32)
    provider = AiProvider.create!(name: 'Encrypted Provider', url: 'https://example.test', api_key: 'secret-ai-key')

    assert_equal 'payer-sensitive@example.com', payment.reload.payer_email
    assert_equal({ 'payer_info' => { 'email_address' => 'payer-sensitive@example.com' } }, payment.raw_attributes)
    assert_equal 'a' * 32, reader.reload.key
    assert_equal 'secret-ai-key', provider.reload.api_key

    assert_no_plaintext raw_row('paypal_payments', payment.id)['payer_email'], 'payer-sensitive@example.com'
    assert_no_plaintext raw_json('paypal_payments', payment.id, 'raw_attributes'), 'payer-sensitive@example.com'
    reader_row = raw_row('rfid_readers', reader.id)
    assert_no_plaintext reader_row['key'], 'a' * 32
    assert_no_plaintext reader_row['key_ciphertext'], 'a' * 32
    assert_no_plaintext raw_row('ai_providers', provider.id)['api_key'], 'secret-ai-key'
    assert_equal reader, RfidReader.lookup_by_key('a' * 32)
  end

  private

  def raw_row(table, id)
    ActiveRecord::Base.connection.exec_query("SELECT * FROM #{table} WHERE id = #{id.to_i}").first
  end

  def raw_json(table, id, column)
    ActiveRecord::Base.connection.select_value("SELECT #{column}::text FROM #{table} WHERE id = #{id.to_i}")
  end

  def assert_no_plaintext(raw_value, plaintext)
    assert raw_value.present?
    assert_not_includes raw_value.to_s, plaintext
  end
end
