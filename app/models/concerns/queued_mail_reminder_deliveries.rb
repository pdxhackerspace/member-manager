module QueuedMailReminderDeliveries
  extend ActiveSupport::Concern

  def record_reminder_deliveries!(sent_time)
    record_slack_signup_reminder_delivery!(sent_time) if slack_signup_reminder_delivery?
    record_application_link_reminder_delivery!(sent_time) if application_link_reminder_delivery?
  end

  private

  def slack_signup_reminder_delivery?
    mailer_action == 'slack_signup_reminder' && recipient.present?
  end

  def record_slack_signup_reminder_delivery!(sent_time)
    Reminders::NotifySlackSignup.record_delivery!(recipient, at: sent_time)
  rescue StandardError => e
    Rails.logger.error(
      "[QueuedMail] slack_signup_reminder stamp failed queued_mail_id=#{id} user_id=#{recipient&.id} " \
      "#{e.class}: #{e.message}"
    )
    raise
  end

  def application_link_reminder_delivery?
    mailer_action == 'application_link_reminder'
  end

  def record_application_link_reminder_delivery!(sent_time)
    verification = ApplicationVerification.by_email(to).order(created_at: :desc).first
    return unless verification

    Reminders::NotifyApplicationLink.record_delivery!(verification, at: sent_time)
  rescue StandardError => e
    Rails.logger.error(
      "[QueuedMail] application_link_reminder stamp failed queued_mail_id=#{id} to=#{to} " \
      "#{e.class}: #{e.message}"
    )
    raise
  end
end
