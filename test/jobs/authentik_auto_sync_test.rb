require 'test_helper'

class AuthentikAutoSyncTest < ActiveJob::TestCase
  setup do
    Current.skip_authentik_sync = false
  end

  teardown do
    Current.skip_authentik_sync = nil
  end

  test 'user info change provisions authentik user when not yet linked' do
    user = users(:two)
    user.update_columns(authentik_id: nil)

    assert_enqueued_with(job: Authentik::ProvisionUserJob, args: [user.id]) do
      user.update!(full_name: 'Needs Authentik Provision')
    end
  end

  test 'manual application group membership change queues authentik membership sync' do
    group = application_groups(:sample_group)
    group.update_columns(authentik_group_id: 'authentik-group-123')
    user = users(:two)

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob) do
      group.users << user unless group.users.include?(user)
    end
  end

  test 'source application group membership change queues sync for dependent groups' do
    group = application_groups(:sample_group)
    group.update_columns(authentik_group_id: nil)
    ApplicationGroup.create!(
      application: group.application,
      name: 'Dependent Sync Group',
      authentik_name: 'sample:dependent-sync-group',
      authentik_group_id: 'dependent-authentik-group',
      member_source: 'sync_group',
      sync_with_group: group
    )
    user = users(:two)

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob) do
      group.users << user unless group.users.include?(user)
    end
  end

  test 'training changes queue trained-in application group membership sync' do
    training = nil

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob, args: [%w[trained_in]]) do
      training = Training.create!(
        trainee: users(:one),
        trainer: users(:two),
        training_topic: training_topics(:laser_cutting),
        trained_at: Time.current
      )
    end

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob, args: [%w[trained_in]]) do
      training.destroy!
    end
  end

  test 'trainer capability changes queue can-train application group membership sync' do
    capability = nil

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob, args: [%w[can_train]]) do
      capability = TrainerCapability.create!(
        user: users(:one),
        training_topic: training_topics(:laser_cutting)
      )
    end

    assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob, args: [%w[can_train]]) do
      capability.destroy!
    end
  end

  test 'provisioning a user queues application group membership sync after authentik id is assigned' do
    user = users(:two)
    user.update_columns(authentik_id: nil, username: 'provision-membership-sync')

    fake_client_class = Class.new do
      def find_user_by_username(_username)
        { 'pk' => 12_345 }
      end

      def update_user(_authentik_id, **_attrs)
        { 'pk' => 12_345 }
      end
    end

    original_client = Authentik.send(:remove_const, :Client)
    Authentik.const_set(:Client, fake_client_class)
    begin
      assert_enqueued_with(job: Authentik::ApplicationGroupMembershipSyncJob) do
        Authentik::ProvisionUserJob.perform_now(user.id)
      end
    ensure
      Authentik.send(:remove_const, :Client)
      Authentik.const_set(:Client, original_client)
    end

    assert_equal '12345', user.reload.authentik_id
  end
end
