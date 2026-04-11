# frozen_string_literal: true

Rails.application.config.after_initialize do
  interceptors = ActionMailer::Base.delivery_interceptors
  next if interceptors.include?(MailDeliveryLogInterceptor)

  ActionMailer::Base.register_interceptor(MailDeliveryLogInterceptor)
end
