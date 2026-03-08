module NormalizesEmail
  extend ActiveSupport::Concern

  class_methods do
    def normalizes_email_field(field_name)
      before_validation do
        self[field_name] = self[field_name].to_s.strip.downcase.presence
      end
    end
  end
end
