module Reminders
  class NotifySlackSignup
    def self.call(now: Time.current)
      new(now: now).call
    end

    def self.record_delivery!(user, at: Time.current)
      user.with_lock do
        user.update!(slack_signup_reminder_sent_at: at)
      end
    end

    def initialize(now:)
      @now = now
    end

    def call
      return unless ReminderSetting.enabled?('slack_signup')
      return unless MemberSource.enabled?('slack')

      SlackSignupEligibility.due(now: @now).find_each { |user| notify_user(user) }
    end

    private

    def notify_user(user)
      user.with_lock do
        return unless SlackSignupEligibility.due?(user, now: @now)

        extras = MemberMailer.slack_signup_template_extras(user, now: @now)
        result = deliver_reminder_mail(user, extras)
        return if result.nil?

        self.class.record_delivery!(user, at: @now) if result.is_a?(QueuedMail::ImmediateDelivery)
      end
    end

    def deliver_reminder_mail(user, extras)
      QueuedMail.enqueue(:slack_signup_reminder, user, reason: 'Slack signup reminder', **extras)
    rescue StandardError => e
      Rails.logger.error("[NotifySlackSignup] user_id=#{user.id} delivery failed: #{e.class}: #{e.message}")
      nil
    end
  end
end
