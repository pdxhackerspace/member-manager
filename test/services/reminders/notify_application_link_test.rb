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

    test 'skips when builtin application is disabled' do
      MembershipSetting.instance.update!(use_builtin_membership_application: false)
      due_verification(email: 'builtin-off@example.com')

      travel_to @now do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          NotifyApplicationLink.call(now: @now)
        end
      end
    end

    test 'queued delivery stamps the verification that triggered the reminder' do
      EmailTemplate.find_by!(key: 'application_link_reminder').update!(send_immediately: false)
      older = due_verification(email: 'same-link@example.com')
      newer = ApplicationVerification.create!(
        email: 'same-link@example.com',
        confirmed_open_house: true,
        confirmed_code_of_conduct: true,
        created_at: @now - 1.day,
        expires_at: @now + 2.days
      )

      travel_to @now do
        NotifyApplicationLink.call(now: @now)
      end

      queued_mail = QueuedMail.order(:created_at).last
      assert_equal older.id, queued_mail.mailer_args['application_verification_id']

      delivery_time = @now + 2.hours
      travel_to delivery_time do
        queued_mail.update!(status: 'approved', reviewed_by: users(:one), reviewed_at: delivery_time)
        queued_mail.deliver_now!
      end

      assert_equal delivery_time, older.reload.application_link_reminder_sent_at
      assert_equal 1, older.application_link_reminder_count
      assert_nil newer.reload.application_link_reminder_sent_at
      assert_equal 0, newer.application_link_reminder_count
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

    test 'raises when delivery succeeds but stamping fails' do
      verification = due_verification(email: 'stamp-failure@example.com')
      original = NotifyApplicationLink.method(:record_delivery!)
      NotifyApplicationLink.define_singleton_method(:record_delivery!) do |*_args|
        raise ActiveRecord::StatementInvalid, 'stamp failed'
      end

      travel_to @now do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          assert_raises(ActiveRecord::StatementInvalid) do
            NotifyApplicationLink.call(now: @now)
          end
        end
      end

      verification.reload
      assert_nil verification.application_link_reminder_sent_at
      assert_equal 0, verification.application_link_reminder_count
    ensure
      NotifyApplicationLink.define_singleton_method(:record_delivery!, original)
    end

    test 'swallows delivery failures without stamping' do
      verification = due_verification(email: 'delivery-failure@example.com')
      original = QueuedMail.method(:enqueue_application_link_reminder)
      QueuedMail.define_singleton_method(:enqueue_application_link_reminder) do |*_args|
        raise StandardError, 'smtp down'
      end

      travel_to @now do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          assert_nothing_raised do
            NotifyApplicationLink.call(now: @now)
          end
        end
      end

      verification.reload
      assert_nil verification.application_link_reminder_sent_at
      assert_equal 0, verification.application_link_reminder_count
    ensure
      QueuedMail.define_singleton_method(:enqueue_application_link_reminder, original)
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
