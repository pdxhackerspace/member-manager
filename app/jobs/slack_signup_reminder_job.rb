class SlackSignupReminderJob < ApplicationJob
  queue_as :default

  def perform
    Reminders::NotifySlackSignup.call
  end
end
