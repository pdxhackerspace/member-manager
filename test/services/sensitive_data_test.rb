require 'test_helper'

# The derived-key fallback has to survive the Member Zone rename. Nothing re-encrypts on
# deploy, so an environment that never set DATABASE_FIELD_ENCRYPTION_KEY or
# EMAIL_LOOKUP_HMAC_KEY loses every encrypted column and every lookup digest the moment a
# salt changes — and the loss is silent, because plaintext-era rows still read fine.
class SensitiveDataTest < ActiveSupport::TestCase
  LEGACY_ENCRYPTION_SALT = 'member-manager-sensitive-data-encryption'.freeze
  LEGACY_HMAC_SALT = 'member-manager-email-lookup-hmac'.freeze

  test 'derivation salts stay pinned to their pre-rename values' do
    assert_equal LEGACY_ENCRYPTION_SALT, SensitiveData::ENCRYPTION_KEY_SALT
    assert_equal LEGACY_HMAC_SALT, SensitiveData::HMAC_KEY_SALT
  end

  test 'derived keys are unchanged by the rename' do
    with_derived_keys do
      assert_equal derived_key(LEGACY_ENCRYPTION_SALT), SensitiveData.send(:encryption_key)
      assert_equal derived_key(LEGACY_HMAC_SALT), SensitiveData.send(:hmac_key)
    end
  end

  test 'ciphertext written before the rename still decrypts' do
    with_derived_keys do
      legacy = ActiveSupport::MessageEncryptor.new(derived_key(LEGACY_ENCRYPTION_SALT), cipher: 'aes-256-gcm')
      stored = "#{SensitiveData::STRING_PREFIX}#{legacy.encrypt_and_sign('member@example.com')}"

      assert_equal 'member@example.com', SensitiveData.decode_string(stored)
    end
  end

  test 'lookup digests written before the rename still match' do
    with_derived_keys do
      legacy_digest = OpenSSL::HMAC.hexdigest('SHA256', derived_key(LEGACY_HMAC_SALT), 'member@example.com')

      assert_equal legacy_digest, SensitiveData.email_digest('Member@Example.com')
    end
  end

  private

  def derived_key(salt)
    ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(salt, 32)
  end

  # Exercises the secret_key_base fallback rather than whatever the environment configures,
  # since the salts only participate when neither key is set explicitly.
  def with_derived_keys
    originals = %w[DATABASE_FIELD_ENCRYPTION_KEY EMAIL_LOOKUP_HMAC_KEY].index_with { |key| ENV.fetch(key, nil) }
    originals.each_key { |key| ENV.delete(key) }
    reset_encryptor!
    yield
  ensure
    originals.each { |key, value| ENV[key] = value unless value.nil? }
    reset_encryptor!
  end

  def reset_encryptor!
    return unless SensitiveData.instance_variable_defined?(:@encryptor)

    SensitiveData.remove_instance_variable(:@encryptor)
  end
end
