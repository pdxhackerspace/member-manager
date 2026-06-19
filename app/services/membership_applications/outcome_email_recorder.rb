module MembershipApplications
  class OutcomeEmailRecorder
    def self.assign!(application, delivery)
      return if delivery.nil?

      case delivery
      when QueuedMail
        application.update!(outcome_queued_mail: delivery)
      when QueuedMail::ImmediateDelivery
        application.update!(
          outcome_email_subject: delivery.subject,
          outcome_email_body_html: delivery.body_html
        )
      end
    end

    def self.for_display(application)
      if application.outcome_queued_mail
        {
          subject: application.outcome_queued_mail.subject,
          body_html: application.outcome_queued_mail.body_html
        }
      elsif application.outcome_email_subject.present?
        {
          subject: application.outcome_email_subject,
          body_html: application.outcome_email_body_html.to_s
        }
      end
    end
  end
end
