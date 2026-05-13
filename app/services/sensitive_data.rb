class SensitiveData
  STRING_PREFIX = 'enc:v1:'.freeze
  JSON_MARKER = '__encrypted_v1__'.freeze

  class << self
    def encrypt(value)
      return nil if value.nil?

      encryptor.encrypt_and_sign(value.to_s)
    end

    def decrypt(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
    end

    def encrypted_string?(value)
      value.is_a?(String) && value.start_with?(STRING_PREFIX)
    end

    def encode_string(value)
      return nil if value.nil?

      "#{STRING_PREFIX}#{encrypt(value)}"
    end

    def decode_string(value)
      return value unless encrypted_string?(value)

      decrypt(value.delete_prefix(STRING_PREFIX))
    end

    def encode_json(value)
      return nil if value.nil?

      { JSON_MARKER => encrypt(JSON.generate(value)) }
    end

    def decode_json(value)
      return value unless encrypted_json?(value)

      JSON.parse(decrypt(value.fetch(JSON_MARKER)))
    end

    def encrypted_json?(value)
      value.is_a?(Hash) && value.key?(JSON_MARKER)
    end

    def normalize_email(value)
      value.to_s.strip.downcase.presence
    end

    def email_digest(value)
      normalized = normalize_email(value)
      return nil if normalized.blank?

      OpenSSL::HMAC.hexdigest('SHA256', hmac_key, normalized)
    end

    def email_digests(values)
      Array(values).filter_map { |value| email_digest(value) }.uniq
    end

    private

    def encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(encryption_key, cipher: 'aes-256-gcm')
    end

    def encryption_key
      configured_key('DATABASE_FIELD_ENCRYPTION_KEY', 'member-manager-sensitive-data-encryption')
    end

    def hmac_key
      configured_key('EMAIL_LOOKUP_HMAC_KEY', 'member-manager-email-lookup-hmac')
    end

    def configured_key(env_name, salt)
      raw = ENV[env_name].presence || Rails.application.credentials.dig(:encryption, env_name.downcase).presence
      return [raw].pack('H*') if raw.to_s.match?(/\A\h{64}\z/)
      return Base64.strict_decode64(raw) if raw.to_s.match?(%r{\A[A-Za-z0-9+/=]{44,}\z})

      secret = raw.presence || Rails.application.secret_key_base
      ActiveSupport::KeyGenerator.new(secret).generate_key(salt, 32)
    end
  end
end
