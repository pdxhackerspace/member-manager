class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch('EMAIL_FROM_ADDRESS', 'noreply@example.com') }
  layout 'mailer'

  after_action :set_member_manager_mail_trace_headers
  around_deliver :log_member_manager_mail_delivery

  private

  def set_member_manager_mail_trace_headers
    headers['X-MemberManager-Mailer'] = self.class.name
    headers['X-MemberManager-Action'] = action_name.to_s
  end

  def log_member_manager_mail_delivery
    yield
    log_direct_mail_delivery!('sent')
  rescue StandardError => e
    log_direct_mail_delivery!('send_failed', details: "#{e.class}: #{e.message}")
    raise
  end

  def log_direct_mail_delivery!(event, details: nil)
    return if message['X-MemberManager-Skip-MailLog']&.decoded.to_s == '1'
    return if message.to.blank? || message.subject.blank?

    MailLogEntry.log_direct_delivery!(
      to: Array(message.to).compact.join(', '),
      subject: message.subject.to_s.truncate(500),
      mailer_class: self.class.name,
      mailer_action: action_name.to_s,
      event: event,
      details: details,
      body_html: mail_body_html,
      body_text: mail_body_text
    )
  end

  def mail_body_html
    return message.html_part&.body&.decoded if message.multipart?
    return message.body.decoded if message.mime_type == 'text/html'

    nil
  end

  def mail_body_text
    return message.text_part&.body&.decoded if message.multipart?
    return message.body.decoded if message.mime_type == 'text/plain'

    nil
  end

  # Helper to get the organization name for emails
  def organization_name
    ENV.fetch('ORGANIZATION_NAME', 'Member Manager')
  end

  # Helper to get the support email
  def support_email
    ENV.fetch('EMAIL_SUPPORT_ADDRESS', ENV.fetch('EMAIL_FROM_ADDRESS', 'support@example.com'))
  end
end
