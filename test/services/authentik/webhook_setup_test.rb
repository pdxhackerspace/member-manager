require 'test_helper'

module Authentik
  class WebhookSetupTest < ActiveSupport::TestCase
    class FakeClient
      attr_accessor :transports, :policies, :rules, :updates

      def initialize
        @transports = []
        @policies = []
        @rules = []
        @updates = []
      end

      def list_notification_transports(name:)
        @transports.select { |t| t['name'] == name }
      end

      def update_notification_transport(primary_key, **attrs)
        @updates << [:transport, primary_key, attrs]
        @transports.find { |t| t['pk'] == primary_key }.merge(attrs.stringify_keys)
      end

      def list_event_matcher_policies(name:)
        @policies.select { |p| p['name'] == name }
      end

      def update_event_matcher_policy(primary_key, **attrs)
        @updates << [:policy, primary_key, attrs]
        @policies.find { |p| p['pk'] == primary_key }.merge(attrs.stringify_keys)
      end

      def list_notification_rules(name:)
        @rules.select { |r| r['name'] == name }
      end

      def update_notification_rule(primary_key, **attrs)
        @updates << [:rule, primary_key, attrs]
        @rules.find { |r| r['pk'] == primary_key }.merge(attrs.stringify_keys)
      end
    end

    setup do
      @client = FakeClient.new
      @setup = WebhookSetup.new(webhook_url: 'https://example.com/webhooks/authentik')
      @setup.instance_variable_set(:@client, @client)
    end

    test 'adopt_transport adopts and renames a pre-rename transport' do
      @client.transports = [{ 'pk' => 'transport-1', 'name' => WebhookSetup::LEGACY_TRANSPORT_NAME }]

      transport = @setup.send(:adopt_transport)

      assert_equal WebhookSetup::TRANSPORT_NAME, transport['name']
      assert_equal [[:transport, 'transport-1', { name: WebhookSetup::TRANSPORT_NAME }]], @client.updates
    end

    test 'adopt_transport prefers the current name when both exist' do
      @client.transports = [
        { 'pk' => 'current', 'name' => WebhookSetup::TRANSPORT_NAME },
        { 'pk' => 'legacy', 'name' => WebhookSetup::LEGACY_TRANSPORT_NAME }
      ]

      transport = @setup.send(:adopt_transport)

      assert_equal 'current', transport['pk']
      assert_empty @client.updates
    end

    test 'adopt_user_policy adopts and renames a pre-rename policy' do
      @client.policies = [{ 'pk' => 'policy-1', 'name' => WebhookSetup::LEGACY_USER_POLICY_NAME }]

      policy = @setup.send(:adopt_user_policy)

      assert_equal WebhookSetup::USER_POLICY_NAME, policy['name']
      assert_equal [[:policy, 'policy-1', { name: WebhookSetup::USER_POLICY_NAME }]], @client.updates
    end

    test 'status reports legacy objects without renaming them in Authentik' do
      @client.transports = [{ 'pk' => 'transport-1', 'name' => WebhookSetup::LEGACY_TRANSPORT_NAME }]
      @client.policies = [{ 'pk' => 'policy-1', 'name' => WebhookSetup::LEGACY_USER_POLICY_NAME }]
      @client.rules = [{ 'pk' => 'rule-1', 'name' => WebhookSetup::LEGACY_RULE_NAME }]

      result = @setup.status

      assert result[:configured]
      assert_equal WebhookSetup::LEGACY_TRANSPORT_NAME, result[:transport][:name]
      assert_equal WebhookSetup::LEGACY_USER_POLICY_NAME, result[:user_policy][:name]
      assert_equal WebhookSetup::LEGACY_RULE_NAME, result[:rule][:name]
      assert_empty @client.updates
    end
  end
end
