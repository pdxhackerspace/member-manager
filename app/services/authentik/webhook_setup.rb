module Authentik
  class WebhookSetup
    TRANSPORT_NAME = 'MemberZone Webhook'.freeze
    USER_POLICY_NAME = 'MemberZone User Events'.freeze
    GROUP_POLICY_NAME = 'MemberZone Group Events'.freeze
    RULE_NAME = 'MemberZone Notifications'.freeze

    LEGACY_TRANSPORT_NAME = 'MemberManager Webhook'.freeze
    LEGACY_USER_POLICY_NAME = 'MemberManager User Events'.freeze
    LEGACY_GROUP_POLICY_NAME = 'MemberManager Group Events'.freeze
    LEGACY_RULE_NAME = 'MemberManager Notifications'.freeze

    attr_reader :client, :webhook_url, :webhook_secret, :admin_group_id

    def initialize(
      webhook_url: nil,
      webhook_secret: AuthentikConfig.settings.webhook_secret,
      admin_group_id: AuthentikConfig.settings.group_id
    )
      @client = Authentik::Client.new
      @webhook_url = webhook_url || default_webhook_url
      @webhook_secret = webhook_secret
      @admin_group_id = admin_group_id
    end

    def setup!
      Rails.logger.info('[Authentik WebhookSetup] Starting webhook configuration...')

      validate_configuration!

      transport = setup_transport!
      user_policy = setup_user_policy!
      group_policy = setup_group_policy!
      rule = setup_notification_rule!(transport)
      bind_policies_to_rule!(rule, [user_policy, group_policy])

      result = {
        success: true,
        transport: transport,
        user_policy: user_policy,
        group_policy: group_policy,
        rule: rule
      }

      Rails.logger.info('[Authentik WebhookSetup] Webhook configuration completed successfully')
      result
    rescue StandardError => e
      Rails.logger.error("[Authentik WebhookSetup] Setup failed: #{e.message}")
      { success: false, error: e.message }
    end

    def teardown!
      Rails.logger.info('[Authentik WebhookSetup] Starting webhook teardown...')

      # Delete in reverse order of dependencies
      delete_notification_rule!
      delete_policies!
      delete_transport!

      Rails.logger.info('[Authentik WebhookSetup] Webhook teardown completed')
      { success: true }
    rescue StandardError => e
      Rails.logger.error("[Authentik WebhookSetup] Teardown failed: #{e.message}")
      { success: false, error: e.message }
    end

    def status
      transport = find_transport
      user_policy = find_user_policy
      group_policy = find_group_policy
      rule = find_rule

      {
        configured: transport.present? && rule.present?,
        transport: if transport
                     { id: transport['pk'], name: transport['name'],
                       webhook_url: transport['webhook_url'] }
                   end,
        user_policy: user_policy ? { id: user_policy['pk'], name: user_policy['name'] } : nil,
        group_policy: group_policy ? { id: group_policy['pk'], name: group_policy['name'] } : nil,
        rule: rule ? { id: rule['pk'], name: rule['name'] } : nil
      }
    end

    private

    def default_webhook_url
      base_url = MemberZoneConfig.base_url
      return nil if base_url.blank?

      # Use the configured slug from IncomingWebhook if available
      webhook = IncomingWebhook.find_by(webhook_type: 'authentik')
      slug = webhook&.slug || 'authentik'

      "#{base_url.delete_suffix('/')}/webhooks/#{slug}"
    end

    def validate_configuration!
      if webhook_url.blank?
        raise ArgumentError,
              'Webhook URL is required. Set MEMBER_ZONE_BASE_URL environment variable.'
      end
      raise ArgumentError, 'Admin group ID is required for notification rule binding.' if admin_group_id.blank?
    end

    # ========== Transport ==========

    def setup_transport!
      existing = find_transport
      if existing
        Rails.logger.info("[Authentik WebhookSetup] Updating existing transport: #{existing['pk']}")
        client.update_notification_transport(
          existing['pk'],
          webhook_url: build_webhook_url,
          mode: 'webhook'
        )
      else
        Rails.logger.info('[Authentik WebhookSetup] Creating new transport')
        client.create_notification_transport(
          name: TRANSPORT_NAME,
          mode: 'webhook',
          webhook_url: build_webhook_url
        )
      end
    end

    def find_transport
      adopt_named_authentik_object(
        current_name: TRANSPORT_NAME,
        legacy_name: LEGACY_TRANSPORT_NAME
      ) { |name| fetch_transport_by_name(name) }
    end

    def delete_transport!
      delete_named_authentik_objects(
        TRANSPORT_NAME,
        LEGACY_TRANSPORT_NAME,
        finder: method(:fetch_transport_by_name),
        deleter: lambda do |transport|
          Rails.logger.info("[Authentik WebhookSetup] Deleting transport: #{transport['pk']}")
          client.delete_notification_transport(transport['pk'])
        end
      )
    end

    def fetch_transport_by_name(name)
      client.list_notification_transports(name: name).find { |t| t['name'] == name }
    end

    def build_webhook_url
      url = webhook_url
      if webhook_secret.present?
        separator = url.include?('?') ? '&' : '?'
        url = "#{url}#{separator}secret=#{webhook_secret}"
      end
      url
    end

    # ========== Policies ==========

    def setup_user_policy!
      existing = find_user_policy
      if existing
        Rails.logger.info("[Authentik WebhookSetup] User policy already exists: #{existing['pk']}")
        existing
      else
        Rails.logger.info('[Authentik WebhookSetup] Creating user event matcher policy')
        client.create_event_matcher_policy(
          name: USER_POLICY_NAME,
          app: 'authentik.core',
          model: 'authentik_core.user'
        )
      end
    end

    def setup_group_policy!
      existing = find_group_policy
      if existing
        Rails.logger.info("[Authentik WebhookSetup] Group policy already exists: #{existing['pk']}")
        existing
      else
        Rails.logger.info('[Authentik WebhookSetup] Creating group event matcher policy')
        client.create_event_matcher_policy(
          name: GROUP_POLICY_NAME,
          app: 'authentik.core',
          model: 'authentik_core.group'
        )
      end
    end

    def find_user_policy
      adopt_named_authentik_object(
        current_name: USER_POLICY_NAME,
        legacy_name: LEGACY_USER_POLICY_NAME
      ) { |name| fetch_policy_by_name(name) }
    end

    def find_group_policy
      adopt_named_authentik_object(
        current_name: GROUP_POLICY_NAME,
        legacy_name: LEGACY_GROUP_POLICY_NAME
      ) { |name| fetch_policy_by_name(name) }
    end

    def fetch_policy_by_name(name)
      client.list_event_matcher_policies(name: name).find { |p| p['name'] == name }
    end

    def delete_policies!
      [
        [USER_POLICY_NAME, LEGACY_USER_POLICY_NAME],
        [GROUP_POLICY_NAME, LEGACY_GROUP_POLICY_NAME]
      ].each do |current_name, legacy_name|
        delete_named_authentik_objects(
          current_name,
          legacy_name,
          finder: method(:fetch_policy_by_name),
          deleter: lambda do |policy|
            bindings = client.list_policy_bindings
            policy_bindings = bindings.select { |b| b['policy'] == policy['pk'] }
            policy_bindings.each do |binding|
              Rails.logger.info("[Authentik WebhookSetup] Deleting policy binding: #{binding['pk']}")
              client.delete_policy_binding(binding['pk'])
            end

            Rails.logger.info("[Authentik WebhookSetup] Deleting policy: #{policy['pk']}")
            client.delete_event_matcher_policy(policy['pk'])
          end
        )
      end
    end

    # ========== Notification Rule ==========

    def setup_notification_rule!(transport)
      existing = find_rule
      if existing
        Rails.logger.info("[Authentik WebhookSetup] Updating existing notification rule: #{existing['pk']}")
        client.update_notification_rule(
          existing['pk'],
          transports: [transport['pk']],
          group: admin_group_id
        )
      else
        Rails.logger.info('[Authentik WebhookSetup] Creating notification rule')
        client.create_notification_rule(
          name: RULE_NAME,
          transports: [transport['pk']],
          group: admin_group_id,
          severity: 'notice'
        )
      end
    end

    def find_rule
      adopt_named_authentik_object(
        current_name: RULE_NAME,
        legacy_name: LEGACY_RULE_NAME
      ) { |name| fetch_rule_by_name(name) }
    end

    def delete_notification_rule!
      delete_named_authentik_objects(
        RULE_NAME,
        LEGACY_RULE_NAME,
        finder: method(:fetch_rule_by_name),
        deleter: lambda do |rule|
          Rails.logger.info("[Authentik WebhookSetup] Deleting notification rule: #{rule['pk']}")
          client.delete_notification_rule(rule['pk'])
        end
      )
    end

    def fetch_rule_by_name(name)
      client.list_notification_rules(name: name).find { |r| r['name'] == name }
    end

    # Prefer the current name, adopt a pre-rename object by renaming it in Authentik, and
    # leave both alone when duplicates already exist (manual merge required).
    def adopt_named_authentik_object(current_name:, legacy_name:)
      current = yield(current_name)
      legacy = yield(legacy_name)

      if current && legacy
        Rails.logger.warn(
          "[Authentik WebhookSetup] Both '#{current_name}' and '#{legacy_name}' exist; using '#{current_name}'"
        )
        return current
      end

      return current if current
      return rename_authentik_object(legacy, current_name) if legacy

      nil
    end

    def rename_authentik_object(object, new_name)
      return object if object['name'] == new_name

      pk = object['pk']
      renamed = case object['name']
                when TRANSPORT_NAME, LEGACY_TRANSPORT_NAME
                  client.update_notification_transport(pk, name: new_name)
                when USER_POLICY_NAME, LEGACY_USER_POLICY_NAME, GROUP_POLICY_NAME, LEGACY_GROUP_POLICY_NAME
                  client.update_event_matcher_policy(pk, name: new_name)
                when RULE_NAME, LEGACY_RULE_NAME
                  client.update_notification_rule(pk, name: new_name)
                else
                  raise ArgumentError, "Unexpected Authentik object name: #{object['name']}"
                end
      renamed.presence || object.merge('name' => new_name)
    end

    def delete_named_authentik_objects(current_name, legacy_name, finder:, deleter:)
      [current_name, legacy_name].uniq.each do |name|
        object = finder.call(name)
        next unless object

        deleter.call(object)
      end
    end

    # ========== Policy Bindings ==========

    def bind_policies_to_rule!(rule, policies)
      existing_bindings = client.list_policy_bindings(target: rule['pk'])

      policies.each_with_index do |policy, index|
        already_bound = existing_bindings.any? { |b| b['policy'] == policy['pk'] }
        if already_bound
          Rails.logger.info("[Authentik WebhookSetup] Policy #{policy['name']} already bound to rule")
          next
        end

        Rails.logger.info("[Authentik WebhookSetup] Binding policy #{policy['name']} to rule")
        client.create_policy_binding(
          policy: policy['pk'],
          target: rule['pk'],
          order: index
        )
      end
    end
  end
end
