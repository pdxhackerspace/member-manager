module Authentik
  class WebhookSetup
    # Shared lookup/adopt helpers for Authentik objects located by display name.
    module NamedObjects
      private

      # Read-only: prefer the current name, fall back to the legacy name, and never mutate
      # Authentik. Used by #status so loading the admin page does not rename objects.
      def lookup_named_authentik_object(current_name:, legacy_name:)
        current = yield(current_name)
        legacy = yield(legacy_name)

        current || legacy
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
    end
  end
end
