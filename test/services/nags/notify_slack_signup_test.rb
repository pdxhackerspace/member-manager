require 'test_helper'

module Nags
  class NotifySlackSignupTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @now = Time.zone.local(2026, 8, 5, 7, 0, 0)
      MembershipSetting.instance.update!(
        slack_signup_nag_initial_delay_days: 7,
        slack_signup_nag_repeat_delay_days: 14
      )
      NagSetting.find_or_create_by!(key: 'slack_signup') do |setting|
        setting.name = 'Slack signup reminder'
        setting.description = 'Test'
        setting.enabled = true
      end
      NagSetting.find_by!(key: 'slack_signup').update!(enabled: true)
      member_sources(:slack).update!(enabled: true)
      EmailTemplate.where(key: 'slack_signup_nag').delete_all
      EmailTemplate.create!(
        key: 'slack_signup_nag',
        name: 'Slack Signup Reminder',
        subject: '{{organization_name}}: Join us on Slack',
        body_html: '<p>Hi {{member_name}}</p>',
        body_text: 'Hi {{member_name}}',
        enabled: true,
        send_immediately: true
      )
    end

    test 'sends reminder and stamps nag time when enabled' do
      user = due_user(email: 'notify-slack@example.com')

      travel_to @now do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          NotifySlackSignup.call(now: @now)
        end
      end

      assert_equal @now, user.reload.slack_signup_nag_sent_at
    end

    test 'skips when nag is disabled' do
      NagSetting.find_by!(key: 'slack_signup').update!(enabled: false)
      due_user(email: 'disabled-nag@example.com')

      travel_to @now do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          NotifySlackSignup.call(now: @now)
        end
      end
    end

    test 'skips when slack source is disabled' do
      member_sources(:slack).update!(enabled: false)
      due_user(email: 'slack-off@example.com')

      travel_to @now do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          NotifySlackSignup.call(now: @now)
        end
      end
    end

    private

    def due_user(email:)
      user = User.create!(
        email: email,
        full_name: 'Slack Notify Target',
        active: true,
        service_account: false,
        membership_status: 'paying',
        dues_status: 'current',
        payment_type: 'unknown'
      )
      MembershipApplication.create!(
        user: user,
        email: email,
        status: 'approved',
        reviewed_at: @now - 10.days,
        submitted_at: @now - 12.days
      )
      user
    end
  end
end
