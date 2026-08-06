require 'test_helper'

class SlackSignupNagJobTest < ActiveJob::TestCase
  setup do
    NagSetting.find_or_create_by!(key: 'slack_signup') do |setting|
      setting.name = 'Slack signup reminder'
      setting.description = 'Test'
      setting.enabled = false
    end
  end

  test 'perform completes when nag is disabled' do
    assert_nil SlackSignupNagJob.perform_now
  end

  test 'perform sends when nag is enabled and members are due' do
    now = Time.zone.local(2026, 8, 5, 7, 0, 0)
    NagSetting.find_by!(key: 'slack_signup').update!(enabled: true)
    member_sources(:slack).update!(enabled: true)
    EmailTemplate.where(key: 'slack_signup_nag').delete_all
    EmailTemplate.create!(
      key: 'slack_signup_nag',
      name: 'Slack Signup Reminder',
      subject: 'Join Slack',
      body_html: '<p>Hi</p>',
      body_text: 'Hi',
      enabled: true,
      send_immediately: true
    )
    user = User.create!(
      email: 'job-nag@example.com',
      full_name: 'Job Nag Target',
      active: true,
      service_account: false,
      membership_status: 'paying',
      dues_status: 'current',
      payment_type: 'unknown'
    )
    MembershipApplication.create!(
      user: user,
      email: user.email,
      status: 'approved',
      reviewed_at: now - 10.days,
      submitted_at: now - 12.days
    )

    travel_to now do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        SlackSignupNagJob.perform_now
      end
    end
  end
end
