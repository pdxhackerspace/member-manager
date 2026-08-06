class SlackSignupNagJob < ApplicationJob
  queue_as :default

  def perform
    Nags::NotifySlackSignup.call
  end
end
