module NormalizesEmail
  extend ActiveSupport::Concern

  class_methods do
    def normalizes_email_field(field_name)
      before_validation do
        public_send("#{field_name}=", public_send(field_name).to_s.strip.downcase.presence)
      end
    end
  end
end
