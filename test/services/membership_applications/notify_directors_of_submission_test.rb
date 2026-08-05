# frozen_string_literal: true

require 'test_helper'

module MembershipApplications
  class NotifyDirectorsOfSubmissionTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      ActionMailer::Base.deliveries.clear
      clear_enqueued_jobs
      EmailTemplate.where(key: 'staff_application_nag').delete_all
      ensure_staff_new_application_template!
      @app = MembershipApplication.create!(email: 'notify-directors@example.com', status: 'submitted')
    end

    teardown do
      clear_enqueued_jobs
    end

    test 'sends one deliver_later mail per reviewer with email' do
      grant_privileges(users(:one), 'applications.review')
      grant_privileges(users(:two), 'applications.review')

      delivery_count_before = ActionMailer::Base.deliveries.size

      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end

      ActionMailer::Base.deliveries.drop(delivery_count_before).each do |mail|
        assert_equal 'staff_new_application', mail['X-MemberZone-Action']&.decoded
        assert_match(/needs review/i, mail.subject)
      end
    end

    test 'deduplicates when two topics confer the same privilege to one user' do
      staff = users(:one)
      grant_privileges(staff, 'applications.review')
      grant_privileges(staff, 'applications.review')

      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'no mail when nobody holds the review privilege' do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'no mail for a topic carrying the role that nobody holds' do
      topic = TrainingTopic.create!(name: 'Unheld reviewer topic')
      role = Role.create!(name: 'Unheld reviewer', privileges: [find_or_create_privilege('applications.review')])
      TrainingTopicRole.create!(training_topic: topic, role: role, member_source: 'trained_in')

      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'admins are not notified just for being admins' do
      users(:one).update!(is_admin: true)

      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'skips staff with blank email' do
      staff = users(:one)
      staff.update_column(:email, '')
      grant_privileges(staff, 'applications.review')

      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    def ensure_staff_new_application_template!
      return if EmailTemplate.exists?(key: 'staff_new_application')

      attrs = EmailTemplate::DEFAULT_TEMPLATES.fetch('staff_new_application')
      EmailTemplate.create!({ key: 'staff_new_application', enabled: true }.merge(attrs))
    end
  end
end
