class AiOllamaHealthCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info(
      '[AiOllamaHealthCheckJob] Starting Ollama/OpenAI-compatible health checks (GET /v1/models per enabled profile)'
    )
    AiOllamaProfile.ordered.each do |profile|
      check_profile(profile)
    end
    Rails.logger.info('[AiOllamaHealthCheckJob] Finished health check pass')
  end

  private

  def check_profile(profile)
    ctx = profile_log_context(profile)
    return mark_disabled(profile, ctx) unless profile.enabled?

    url = profile.effective_base_url
    return mark_not_configured(profile, ctx) if url.blank?

    run_check(profile, ctx, url)
  end

  def mark_disabled(profile, ctx)
    Rails.logger.info("[AiOllamaHealthCheckJob] Skip #{ctx}: disabled — last_health_check_at updated only")
    profile.update_columns(
      last_health_check_at: Time.current,
      updated_at: Time.current
    )
  end

  def mark_not_configured(profile, ctx)
    Rails.logger.warn(
      "[AiOllamaHealthCheckJob] Not configured #{ctx}: " \
      "effective_base_url is blank after resolution — #{resolution_hint(profile)}"
    )
    profile.record_not_configured!
  end

  def run_check(profile, ctx, url)
    Rails.logger.info("[AiOllamaHealthCheckJob] Checking #{ctx}")
    result = Ollama::HealthCheck.call(
      base_url: url,
      api_key: profile.effective_api_key,
      profile_id: profile.id,
      profile_key: profile.key
    )
    if result.ok
      Rails.logger.info("[AiOllamaHealthCheckJob] Healthy #{ctx}")
      profile.record_health_success!
    else
      Rails.logger.warn("[AiOllamaHealthCheckJob] Unhealthy #{ctx}: #{result.error}")
      profile.record_health_failure!(result.error)
    end
  end

  def profile_log_context(profile)
    "profile_id=#{profile.id} key=#{profile.key} name=#{profile.name.inspect}"
  end

  # Helps admins see what was configured when the resolved URL is still blank.
  def resolution_hint(profile)
    flags = []
    flags << 'provider_url_override' if profile.provider_url_override.to_s.strip.present?
    flags << 'ai_provider' if profile.ai_provider_id.present?
    flags << 'base_url' if profile.base_url.to_s.strip.present?
    flags << 'non_default_profile' if profile.key != 'default'
    if flags.any?
      "configured: #{flags.join(', ')} (effective_base_url still blank — check provider URL / Default profile)"
    else
      'configured: (none — set provider, override, or base URL)'
    end
  end
end
