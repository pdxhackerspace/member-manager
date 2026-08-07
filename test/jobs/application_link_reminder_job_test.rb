require 'test_helper'

class ApplicationLinkReminderJobTest < ActiveJob::TestCase
  test 'perform completes when reminder is disabled' do
    ReminderSetting.find_or_create_by!(key: 'application_link') do |setting|
      setting.name = 'Application link reminder'
      setting.description = 'Test'
      setting.enabled = false
    end

    assert_nil ApplicationLinkReminderJob.perform_now
  end
end
