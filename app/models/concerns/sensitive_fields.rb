module SensitiveFields
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/BlockLength
  class_methods do
    def encrypts_sensitive_string(*field_names)
      field_names.each do |field_name|
        define_sensitive_string_accessors(field_name)
      end
    end

    def encrypts_sensitive_json(*field_names)
      field_names.each do |field_name|
        define_sensitive_json_accessors(field_name)
      end
    end

    def encrypts_sensitive_string_array(*field_names)
      field_names.each do |field_name|
        define_sensitive_string_array_accessors(field_name)
      end
    end

    def has_email_lookup(field_name, digest_column:)
      digest_writer = proc do
        self[digest_column] = SensitiveData.email_digest(public_send(field_name)) if has_attribute?(digest_column)
      end
      before_validation(&digest_writer)
      before_save(&digest_writer)

      scope :"by_#{field_name}", lambda { |email|
        digest = SensitiveData.email_digest(email)
        normalized = SensitiveData.normalize_email(email)
        if digest.present?
          where(digest_column => digest).or(where("LOWER(#{table_name}.#{field_name}) = ?", normalized))
        else
          none
        end
      }
    end

    private

    def define_sensitive_string_accessors(field_name)
      define_method(field_name) do
        SensitiveData.decode_string(self[field_name])
      end

      define_method("#{field_name}=") do |value|
        normalized = value.presence
        self[field_name] = normalized.nil? ? nil : SensitiveData.encode_string(normalized)
      end
    end

    def define_sensitive_json_accessors(field_name)
      define_method(field_name) do
        SensitiveData.decode_json(self[field_name])
      end

      define_method("#{field_name}=") do |value|
        self[field_name] = value.nil? ? nil : SensitiveData.encode_json(value)
      end
    end

    def define_sensitive_string_array_accessors(field_name)
      define_method(field_name) do
        Array(self[field_name]).map { |value| SensitiveData.decode_string(value) }
      end

      define_method("#{field_name}=") do |values|
        encrypted_values = Array(values).filter_map do |value|
          normalized = value.to_s.strip.presence
          SensitiveData.encode_string(normalized) if normalized.present?
        end
        self[field_name] = encrypted_values
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
