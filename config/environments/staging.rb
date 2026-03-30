require_relative 'production'

Rails.application.configure do
  # Staging mirrors production (see production.rb) but never sends real email.
  # Browse captured messages at /letter_opener (LetterOpenerWeb).
  #
  # If web and Sidekiq run in separate containers, set a shared volume for
  # LetterOpenerWeb’s letters path or configure config.letters_location accordingly.
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false

  # SMTP is not used in staging; delivery goes through letter_opener_web only.
end
