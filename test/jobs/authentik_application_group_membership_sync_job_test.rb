require 'test_helper'

class AuthentikApplicationGroupMembershipSyncJobTest < ActiveJob::TestCase
  setup do
    @settings = AuthentikConfig.settings
    @original_api_token = @settings.api_token
    @original_api_base_url = @settings.api_base_url
    @settings.api_token = 'test-token'
    @settings.api_base_url = 'https://authentik.example.test'
  end

  teardown do
    @settings.api_token = @original_api_token
    @settings.api_base_url = @original_api_base_url
  end

  test 'syncs Authentik groups that depend on changed source groups' do
    source_group = application_groups(:sample_group)
    source_group.update!(authentik_group_id: nil)

    dependent_group = ApplicationGroup.create!(
      application: applications(:sample_app),
      name: 'Dependent Sync Group',
      authentik_name: 'sample:dependent-sync-group',
      authentik_group_id: 'dependent-authentik-group',
      member_source: 'sync_group',
      sync_with_group: source_group
    )

    nested_dependent_group = ApplicationGroup.create!(
      application: applications(:sample_app),
      name: 'Nested Dependent Sync Group',
      authentik_name: 'sample:nested-dependent-sync-group',
      authentik_group_id: 'nested-dependent-authentik-group',
      member_source: 'sync_group',
      sync_with_group: dependent_group
    )

    fake_client = Class.new do
      class << self
        attr_accessor :requested_group_ids
      end
      self.requested_group_ids = []

      def get_group(group_id)
        self.class.requested_group_ids << group_id
        { 'users' => [] }
      end

      def set_group_users(_group_id, _user_ids); end
    end

    original_client = Authentik.send(:remove_const, :Client)
    Authentik.const_set(:Client, fake_client)
    begin
      Authentik::ApplicationGroupMembershipSyncJob.perform_now(%w[manual])
    ensure
      Authentik.send(:remove_const, :Client)
      Authentik.const_set(:Client, original_client)
    end

    assert_equal [dependent_group.authentik_group_id, nested_dependent_group.authentik_group_id],
                 fake_client.requested_group_ids
  end
end
