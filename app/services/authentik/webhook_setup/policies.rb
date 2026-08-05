module Authentik
  class WebhookSetup
    module Policies
      private

      def setup_user_policy!
        existing = adopt_user_policy
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
        existing = adopt_group_policy
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

      def lookup_user_policy
        lookup_named_authentik_object(
          current_name: USER_POLICY_NAME,
          legacy_name: LEGACY_USER_POLICY_NAME
        ) { |name| fetch_policy_by_name(name) }
      end

      def adopt_user_policy
        adopt_named_authentik_object(
          current_name: USER_POLICY_NAME,
          legacy_name: LEGACY_USER_POLICY_NAME
        ) { |name| fetch_policy_by_name(name) }
      end

      def lookup_group_policy
        lookup_named_authentik_object(
          current_name: GROUP_POLICY_NAME,
          legacy_name: LEGACY_GROUP_POLICY_NAME
        ) { |name| fetch_policy_by_name(name) }
      end

      def adopt_group_policy
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
    end
  end
end
