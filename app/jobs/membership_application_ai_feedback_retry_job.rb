class MembershipApplicationAiFeedbackRetryJob < ApplicationJob
  queue_as :default

  def perform
    MembershipApplication.ai_feedback_unprocessed.order(:id).find_each do |application|
      MembershipApplications::ProcessAiFeedback.call(application: application)
    end
  end
end
