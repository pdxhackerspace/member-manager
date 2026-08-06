module Nags
  class NotifySlackSignup
    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
    end

    def call
      return unless NagSetting.enabled?('slack_signup')
      return unless MemberSource.enabled?('slack')

      SlackSignupEligibility.due(now: @now).find_each { |user| notify_user(user) }
    end

    private

    def notify_user(user)
      user.with_lock do
        return unless SlackSignupEligibility.due?(user, now: @now)

        extras = MemberMailer.slack_signup_template_extras(user, now: @now)
        QueuedMail.enqueue(:slack_signup_nag, user, reason: 'Slack signup reminder', **extras)
        user.update!(slack_signup_nag_sent_at: @now)
      end
    rescue StandardError => e
      Rails.logger.error("[NotifySlackSignup] user_id=#{user&.id} #{e.class}: #{e.message}")
    end
  end
end
