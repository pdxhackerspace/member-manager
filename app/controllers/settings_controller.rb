class SettingsController < AuthenticatedController
  include SettingsHelper

  before_action :require_a_visible_setting!

  def index
    @settings_attention_counts = {
      access_controllers: access_controller_issue_count,
      ai_services: AiOllamaProfile.ordered.count(&:urgent_health_issue?),
      email_templates: EmailTemplate.needs_review.count,
      interests: Interest.needs_review.count,
      payment_processors: PaymentProcessor.enabled.where(sync_status: %w[degraded failing]).count,
      recharge: RechargePayment.where(user_id: nil, dont_link: false).count,
      nags_due: nags_due_attention_count
    }
  end

  private

  # The hub is a directory, so it opens for anyone with somewhere to go rather than
  # requiring a settings.view grant that no role hands out. An account with no visible row
  # would only see an empty page, so it is turned away here instead.
  def require_a_visible_setting!
    return if current_user_admin? || can?(:'settings.view')
    return if visible_settings_items.any?

    redirect_to root_path, alert: 'You do not have access to that section.'
  end

  def access_controller_issue_count
    enabled_controllers = AccessController.enabled
    enabled_controllers.where(ping_status: 'failed').count +
      enabled_controllers.where(sync_status: 'failed').count +
      enabled_controllers.where(backup_status: 'failed').count
  end

  def nags_due_attention_count
    return 0 unless NagSetting.enabled?('slack_signup')
    return 0 unless MemberSource.enabled?('slack')

    Nags::SlackSignupEligibility.count_due
  end
end
