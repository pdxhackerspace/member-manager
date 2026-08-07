class SettingsController < AdminController
  def index
    @settings_attention_counts = {
      access_controllers: access_controller_issue_count,
      ai_services: AiOllamaProfile.ordered.count(&:urgent_health_issue?),
      email_templates: EmailTemplate.needs_review.count,
      interests: Interest.needs_review.count,
      payment_processors: PaymentProcessor.enabled.where(sync_status: %w[degraded failing]).count,
      recharge: RechargePayment.where(user_id: nil, dont_link: false).count,
      reminders_due: reminders_due_attention_count
    }
  end

  private

  def access_controller_issue_count
    enabled_controllers = AccessController.enabled
    enabled_controllers.where(ping_status: 'failed').count +
      enabled_controllers.where(sync_status: 'failed').count +
      enabled_controllers.where(backup_status: 'failed').count
  end

  def reminders_due_attention_count
    slack_due = if ReminderSetting.enabled?('slack_signup') && MemberSource.enabled?('slack')
                  Reminders::SlackSignupEligibility.count_due
                else
                  0
                end
    application_link_due = if ReminderSetting.enabled?('application_link')
                             Reminders::ApplicationLinkEligibility.count_due
                           else
                             0
                           end

    slack_due + application_link_due
  end
end
