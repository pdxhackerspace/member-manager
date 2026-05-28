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

    test 'sends one deliver_later mail per trained staff with email' do
      ed = TrainingTopic.create!(name: MembershipApplication::EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)
      aed = TrainingTopic.create!(name: MembershipApplication::ASSISTANT_EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)
      u1 = users(:one)
      u2 = users(:two)
      Training.create!(trainee: u1, training_topic: ed, trained_at: Time.current)
      Training.create!(trainee: u2, training_topic: aed, trained_at: Time.current)

      delivery_count_before = ActionMailer::Base.deliveries.size

      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end

      ActionMailer::Base.deliveries.drop(delivery_count_before).each do |mail|
        assert_equal 'staff_new_application', mail['X-MemberManager-Action']&.decoded
        assert_match(/needs review/i, mail.subject)
      end
    end

    test 'deduplicates when one user holds both trainings' do
      ed = TrainingTopic.create!(name: MembershipApplication::EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)
      aed = TrainingTopic.create!(name: MembershipApplication::ASSISTANT_EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)
      u1 = users(:one)
      Training.create!(trainee: u1, training_topic: ed, trained_at: Time.current)
      Training.create!(trainee: u1, training_topic: aed, trained_at: Time.current)

      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'no mail when no matching training topics exist' do
      TrainingTopic.where(name: MembershipApplication::STAFF_APPLICATION_ALERT_TRAINING_TOPIC_NAMES).delete_all

      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'no mail when topics exist but nobody is trained' do
      TrainingTopic.create!(name: MembershipApplication::EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)

      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
          NotifyDirectorsOfSubmission.call(@app)
        end
      end
    end

    test 'skips staff with blank email' do
      topic = TrainingTopic.create!(name: MembershipApplication::EXECUTIVE_DIRECTOR_TRAINING_TOPIC_NAME)
      staff = users(:one)
      staff.update_column(:email, '')
      Training.create!(trainee: staff, training_topic: topic, trained_at: Time.current)

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
