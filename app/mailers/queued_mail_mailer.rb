class QueuedMailMailer < ApplicationMailer
  def deliver_queued(queued_mail)
    @body_html = queued_mail.body_html
    @body_text = queued_mail.body_text

    mail(to: queued_mail.to, subject: queued_mail.subject) do |format|
      format.html { render html: @body_html.html_safe, layout: 'mailer' }
      format.text { render plain: @body_text } if @body_text.present?
    end
  end
end
