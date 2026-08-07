module Reminders
  class NotifyApplicationLink
    def self.call(now: Time.current)
      new(now: now).call
    end

    def self.record_delivery!(verification, at: Time.current)
      verification.with_lock do
        verification.update!(
          application_link_reminder_sent_at: at,
          application_link_reminder_count: verification.application_link_reminder_count + 1
        )
      end
    end

    def initialize(now:)
      @now = now
    end

    def call
      return unless ReminderSetting.enabled?('application_link')
      return unless MembershipSetting.use_builtin_membership_application?

      ApplicationLinkEligibility.due(now: @now).find_each { |verification| notify_verification(verification) }
    end

    private

    def notify_verification(verification)
      verification.with_lock do
        return unless ApplicationLinkEligibility.due?(verification, now: @now)

        extras = MemberMailer.application_link_template_extras(verification)
        result = deliver_reminder_mail(verification, extras)
        return if result.nil?

        self.class.record_delivery!(verification, at: @now) if result.is_a?(QueuedMail::ImmediateDelivery)
      end
    rescue StandardError => e
      Rails.logger.error(
        "[NotifyApplicationLink] verification_id=#{verification&.id} delivery failed: #{e.class}: #{e.message}"
      )
    end

    def deliver_reminder_mail(verification, extras)
      QueuedMail.enqueue_application_link_reminder(verification, reason: 'Application link reminder', **extras)
    end
  end
end
