require 'test_helper'

module Reminders
  class NotifyApplicationLinkTest < ActiveSupport::TestCase
    setup do
      @now = Time.zone.local(2026, 8, 6, 7, 15, 0)
      MembershipSetting.instance.update!(
        application_link_reminder_delay_days: 3,
        application_link_reminder_max_count: 3,
        use_builtin_membership_application: true
      )
      ReminderSetting.find_or_create_by!(key: 'application_link') do |setting|
        setting.name = 'Application link reminder'
        setting.description = 'Test'
        setting.enabled = true
      end
      ReminderSetting.find_by!(key: 'application_link').update!(enabled: true)
      EmailTemplate.where(key: 'application_link_reminder').delete_all
      EmailTemplate.create!(
        key: 'application_link_reminder',
        name: 'Application Link Reminder',
        subject: '{{organization_name}}: Complete your membership application',
        body_html: '<p>{{application_url}}</p>',
        body_text: 'Continue: {{application_url}}',
        enabled: true,
        send_immediately: true
      )
    end

    test 'sends reminder and stamps verification when enabled' do
      verification = due_verification(email: 'notify-link@example.com')

      travel_to @now do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          NotifyApplicationLink.call(now: @now)
        end
      end

      verification.reload
      assert_equal @now, verification.application_link_reminder_sent_at
      assert_equal 1, verification.application_link_reminder_count
    end

    test 'skips when reminder is disabled' do
      ReminderSetting.find_by!(key: 'application_link').update!(enabled: false)
      due_verification(email: 'disabled-link@example.com')

      travel_to @now do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          NotifyApplicationLink.call(now: @now)
        end
      end
    end

    test 'does not stamp reminder time when mail is queued for review' do
      EmailTemplate.find_by!(key: 'application_link_reminder').update!(send_immediately: false)
      verification = due_verification(email: 'queued-link@example.com')

      travel_to @now do
        assert_difference 'QueuedMail.count', 1 do
          assert_no_difference -> { ActionMailer::Base.deliveries.size } do
            NotifyApplicationLink.call(now: @now)
          end
        end
      end

      verification.reload
      assert_nil verification.application_link_reminder_sent_at
      assert_equal 0, verification.application_link_reminder_count
    end

    private

    def due_verification(email:)
      ApplicationVerification.create!(
        email: email,
        confirmed_open_house: true,
        confirmed_code_of_conduct: true,
        created_at: @now - 4.days,
        expires_at: @now + 2.days
      )
    end
  end
end
