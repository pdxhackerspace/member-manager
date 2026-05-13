# frozen_string_literal: true

# Logs every outgoing Action Mailer message to +MailLogEntry+ (except +QueuedMailMailer+,
# which is already logged via +QueuedMail#deliver_now!+).
class MailDeliveryLogInterceptor
  def self.delivering_email(mail)
    return if mail['X-MemberManager-Skip-MailLog']&.decoded.to_s == '1'

    to = Array(mail.to).compact.join(', ')
    return if to.blank? || mail.subject.blank?

    MailLogEntry.log_direct_delivery!(
      to: to,
      subject: mail.subject.to_s.truncate(500),
      mailer_class: mail['X-MemberManager-Mailer']&.decoded,
      mailer_action: mail['X-MemberManager-Action']&.decoded,
      details: nil,
      body_html: mail_body_html(mail),
      body_text: mail_body_text(mail)
    )
  end

  def self.mail_body_html(mail)
    return mail.html_part&.body&.decoded if mail.multipart?
    return mail.body.decoded if mail.mime_type == 'text/html'

    nil
  end

  def self.mail_body_text(mail)
    return mail.text_part&.body&.decoded if mail.multipart?
    return mail.body.decoded if mail.mime_type == 'text/plain'

    nil
  end
end
