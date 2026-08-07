class ApplicationLinkReminderJob < ApplicationJob
  queue_as :default

  def perform
    Reminders::NotifyApplicationLink.call
  end
end
