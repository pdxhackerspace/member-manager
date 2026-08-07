require 'test_helper'

module Reminders
  class SlackSignupEligibilityTest < ActiveSupport::TestCase
    setup do
      MembershipSetting.instance.update!(
        slack_signup_reminder_initial_delay_days: 7,
        slack_signup_reminder_repeat_delay_days: 14
      )
    end

    test 'due includes active members without slack past initial delay' do
      now = Time.zone.local(2026, 8, 5, 7, 0, 0)
      user = eligible_user(now: now, email: 'needs-slack@example.com')

      travel_to now do
        assert_includes SlackSignupEligibility.due(now: now), user
      end
    end

    test 'due excludes members with linked slack users' do
      now = Time.zone.local(2026, 8, 5, 7, 0, 0)
      user = eligible_user(now: now, email: 'has-slack@example.com')
      SlackUser.create!(
        slack_id: 'U-HAS-SLACK',
        username: 'linked',
        real_name: user.full_name,
        email: user.email,
        user_id: user.id,
        is_bot: false,
        deleted: false
      )

      travel_to now do
        assert_not_includes SlackSignupEligibility.due(now: now), user
      end
    end

    test 'due excludes members nagged inside repeat window' do
      now = Time.zone.local(2026, 8, 5, 7, 0, 0)
      user = eligible_user(now: now, email: 'recent-nag@example.com', slack_signup_reminder_sent_at: now - 3.days)

      travel_to now do
        assert_not_includes SlackSignupEligibility.due(now: now), user
      end
    end

    test 'due excludes members with pending slack signup reminder mail' do
      now = Time.zone.local(2026, 8, 5, 7, 0, 0)
      user = eligible_user(now: now, email: 'pending-nag-mail@example.com')
      QueuedMail.create!(
        to: user.email,
        subject: 'Join us on Slack',
        body_html: '<p>Hi</p>',
        body_text: 'Hi',
        reason: 'Slack signup reminder',
        mailer_action: 'slack_signup_reminder',
        recipient: user,
        status: 'pending'
      )

      travel_to now do
        assert_not_includes SlackSignupEligibility.due(now: now), user
        assert_not SlackSignupEligibility.due?(user, now: now)
      end
    end

    private

    def eligible_user(now:, email:, **attrs)
      reminder_sent_at = attrs.delete(:slack_signup_reminder_sent_at)
      active_override = attrs.delete(:active)

      user = User.create!(
        {
          email: email,
          full_name: 'Slack Reminder Candidate',
          active: true,
          service_account: false,
          membership_status: 'paying',
          dues_status: 'current',
          payment_type: 'unknown'
        }.merge(attrs)
      )

      column_updates = {}
      column_updates[:active] = active_override unless active_override.nil?
      column_updates[:slack_signup_reminder_sent_at] = reminder_sent_at unless reminder_sent_at.nil?
      user.update_columns(column_updates) if column_updates.any?
      MembershipApplication.create!(
        user: user,
        email: email,
        status: 'approved',
        reviewed_at: now - 10.days,
        submitted_at: now - 12.days
      )
      user
    end
  end
end
