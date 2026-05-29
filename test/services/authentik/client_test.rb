require 'test_helper'

module Authentik
  class ClientTest < ActiveSupport::TestCase
    test 'normalize_member reads nested user object fields' do
      client = Authentik::Client.new(base_url: 'https://authentik.example.test', token: 'test-token')

      member = client.send(:normalize_member, {
                             'pk' => 'membership-row',
                             'is_active' => true,
                             'user_obj' => {
                               'pk' => 123,
                               'email' => 'user@example.com',
                               'name' => 'Nested User',
                               'username' => 'nesteduser'
                             }
                           })

      assert_equal '123', member[:authentik_id]
      assert_equal 'user@example.com', member[:email]
      assert_equal 'Nested User', member[:full_name]
      assert_equal 'nesteduser', member[:username]
      assert member[:active]
    end

    test 'normalize_member hydrates incomplete identity fields from user endpoint' do
      client = Authentik::Client.new(base_url: 'https://authentik.example.test', token: 'test-token')
      requested_ids = []

      client.define_singleton_method(:get_user) do |authentik_id|
        requested_ids << authentik_id.to_s
        {
          'pk' => 123,
          'email' => 'hydrated@example.com',
          'name' => 'Hydrated User',
          'username' => 'hydrateduser',
          'is_active' => true
        }
      end

      member = client.send(:normalize_member, {
                             'pk' => 123,
                             'name' => 'Partial User',
                             'is_active' => true
                           })

      assert_equal '123', member[:authentik_id]
      assert_equal 'hydrated@example.com', member[:email]
      assert_equal 'Hydrated User', member[:full_name]
      assert_equal 'hydrateduser', member[:username]
      assert_equal ['123'], requested_ids
    end

    test 'update_user merges attributes with existing Authentik user attributes' do
      client = Authentik::Client.new(base_url: 'https://authentik.example.test', token: 'test-token')
      captured_body = nil

      client.define_singleton_method(:get_user) do |_authentik_id|
        { 'attributes' => { 'rfid' => 'EXISTING-RFID', 'member_manager_id' => '99' } }
      end
      client.define_singleton_method(:patch_json) do |_path, body|
        captured_body = body
        { 'pk' => 123 }
      end

      client.update_user(
        123,
        attributes: { 'slack_user_id' => 'U123', 'slack_handle' => 'alice' }
      )

      assert_equal(
        {
          'rfid' => 'EXISTING-RFID',
          'member_manager_id' => '99',
          'slack_user_id' => 'U123',
          'slack_handle' => 'alice'
        },
        captured_body[:attributes]
      )
    end
  end
end
