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

    test 'does not stamp nag time when mail is queued for review' do
      EmailTemplate.find_by!(key: 'slack_signup_nag').update!(send_immediately: false)
      user = due_user(email: 'queued-nag@example.com')

      travel_to @now do
        assert_difference 'QueuedMail.count', 1 do
          assert_no_difference -> { ActionMailer::Base.deliveries.size } do
            NotifySlackSignup.call(now: @now)
          end
        end
      end

      assert_nil user.reload.slack_signup_nag_sent_at
    end

    test 'stamps nag time when queued mail is delivered' do
      EmailTemplate.find_by!(key: 'slack_signup_nag').update!(send_immediately: false)
      user = due_user(email: 'queued-deliver@example.com')

      travel_to @now do
        NotifySlackSignup.call(now: @now)
      end

      queued_mail = QueuedMail.order(:created_at).last
      assert_equal user, queued_mail.recipient
      assert_nil user.reload.slack_signup_nag_sent_at

      delivery_time = @now + 2.hours
      travel_to delivery_time do
        queued_mail.update!(status: 'approved', reviewed_by: users(:one), reviewed_at: delivery_time)
        queued_mail.deliver_now!
      end

      assert_equal delivery_time, user.reload.slack_signup_nag_sent_at
    end

    test 'queued delivery keeps sent_at when slack nag stamp fails' do
      EmailTemplate.find_by!(key: 'slack_signup_nag').update!(send_immediately: false)
      user = due_user(email: 'queued-stamp-fail@example.com')

      travel_to @now do
        NotifySlackSignup.call(now: @now)
      end

      queued_mail = QueuedMail.order(:created_at).last
      delivery_time = @now + 2.hours
      recipient = queued_mail.recipient

      def recipient.update!(attrs)
        raise ActiveRecord::ActiveRecordError, 'stamp failed' if attrs.key?(:slack_signup_nag_sent_at)

        super
      end

      travel_to delivery_time do
        queued_mail.update!(status: 'approved', reviewed_by: users(:one), reviewed_at: delivery_time)

        assert_raises(ActiveRecord::ActiveRecordError) do
          queued_mail.deliver_now!
        end
      end

      queued_mail.reload
      assert_equal delivery_time, queued_mail.sent_at
      assert_nil queued_mail.last_error
      assert_nil user.reload.slack_signup_nag_sent_at
    end

    test 'does not stamp nag time when template is disabled' do
      EmailTemplate.find_by!(key: 'slack_signup_nag').update!(enabled: false)
      user = due_user(email: 'disabled-template@example.com')

      travel_to @now do
        assert_difference 'QueuedMail.count', 1 do
          assert_no_difference -> { ActionMailer::Base.deliveries.size } do
            NotifySlackSignup.call(now: @now)
          end
        end
      end

      assert_nil user.reload.slack_signup_nag_sent_at
    end

    test 'raises when delivery succeeds but stamp fails' do
      user = due_user(email: 'stamp-fail@example.com')
      service = NotifySlackSignup.new(now: @now)

      def user.update!(attrs)
        raise ActiveRecord::ActiveRecordError, 'stamp failed' if attrs.key?(:slack_signup_nag_sent_at)

        super
      end

      travel_to @now do
        assert_raises(ActiveRecord::ActiveRecordError) do
          service.send(:notify_user, user)
        end
      end

      assert_nil user.reload.slack_signup_nag_sent_at
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
