module Ollama
  class HealthCheck
    TIMEOUT = 5
    PATH = '/v1/models'.freeze
    BODY_LOG_LIMIT = 400

    def self.call(base_url:, api_key: nil, profile_id: nil, profile_key: nil)
      new(
        base_url: base_url,
        api_key: api_key,
        profile_id: profile_id,
        profile_key: profile_key
      ).call
    end

    def initialize(base_url:, api_key: nil, profile_id: nil, profile_key: nil)
      @root = base_url.to_s.strip.chomp('/')
      @api_key = api_key.to_s.strip
      @profile_id = profile_id
      @profile_key = profile_key
    end

    def call
      return failure_blank_root if @root.blank?

      log_request_start
      response = faraday_get_models
      return failure_http(response) unless response.success?

      success_after_json_parse(response)
    rescue JSON::ParserError => e
      failure_json_parse(e, response)
    rescue Faraday::Error => e
      failure_faraday(e)
    rescue StandardError => e
      log_unexpected_error(e)
      raise
    end

    Result = Struct.new(:ok, :error)

    private

    def failure_blank_root
      log_failure('blank_base_url', 'Base URL is blank after normalization')
      Result.new(ok: false, error: 'Base URL is blank')
    end

    def log_request_start
      Rails.logger.info(
        "#{log_tag} GET #{PATH} endpoint=#{safe_endpoint_label} " \
        "auth=#{auth_mode} timeout_open=#{TIMEOUT}s timeout_read=#{TIMEOUT}s"
      )
    end

    def faraday_get_models
      conn = Faraday.new(url: @root) do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = TIMEOUT
        f.adapter Faraday.default_adapter
      end
      conn.get(PATH) do |req|
        req.headers['Authorization'] = "Bearer #{@api_key}" if @api_key.present?
      end
    end

    def failure_http(response)
      preview = body_preview_for_log(response.body)
      ct = response.headers['Content-Type'].to_s.presence || '(none)'
      msg = "HTTP #{response.status}"
      log_failure(
        'http_error',
        "#{msg} content_type=#{ct} body_preview=#{preview}",
        http_status: response.status
      )
      Result.new(ok: false, error: msg)
    end

    def success_after_json_parse(response)
      JSON.parse(response.body)
      Rails.logger.info("#{log_tag} #{PATH} succeeded (JSON parsed)")
      Result.new(ok: true, error: nil)
    end

    def failure_json_parse(error, response)
      preview = body_preview_for_log(response&.body)
      log_failure('json_parse_error', "#{error.class}: #{error.message} body_preview=#{preview}")
      Result.new(ok: false, error: "Invalid response: #{error.message}")
    end

    def failure_faraday(error)
      log_failure(
        'faraday_error',
        "#{error.class.name}: #{error.message.presence || '(no message)'}",
        faraday_class: error.class.name
      )
      Result.new(ok: false, error: error.message.presence || error.class.name)
    end

    def log_unexpected_error(error)
      Rails.logger.error(
        "#{log_tag} unexpected #{error.class.name}: #{error.message} — " \
        "#{Array(error.backtrace).first(5).join(' | ')}"
      )
    end

    def log_tag
      parts = ['[Ollama::HealthCheck]']
      parts << "profile_id=#{@profile_id}" if @profile_id.present?
      parts << "profile_key=#{@profile_key}" if @profile_key.present?
      parts.join(' ')
    end

    def auth_mode
      @api_key.present? ? 'bearer' : 'none'
    end

    def safe_endpoint_label
      uri = URI.parse(@root)
      return @root.truncate(120) unless uri.host

      hostpart = +uri.host
      hostpart << ":#{uri.port}" if uri.port && [80, 443].exclude?(uri.port.to_i)

      uri.scheme.present? ? "#{uri.scheme}://#{hostpart}" : hostpart
    rescue URI::InvalidURIError
      @root.truncate(120)
    end

    def body_preview_for_log(body)
      raw = body.to_s.gsub(/\s+/, ' ').strip
      return '(empty)' if raw.blank?

      raw.length > BODY_LOG_LIMIT ? "#{raw[0, BODY_LOG_LIMIT]}…(truncated)" : raw
    end

    def log_failure(reason, detail, **extra)
      suffix = extra.compact_blank.map { |k, v| "#{k}=#{v}" }.join(' ')
      msg = "#{log_tag} FAILED reason=#{reason} #{detail}"
      msg = "#{msg} #{suffix}" if suffix.present?
      Rails.logger.warn(msg)
    end
  end
end
