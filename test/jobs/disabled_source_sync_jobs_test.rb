require 'test_helper'
require 'minitest/mock'

class DisabledSourceSyncJobsTest < ActiveJob::TestCase
  # ─── Authentik::GroupSyncJob ────────────────────────────────────

  test 'Authentik::GroupSyncJob skips when authentik source is disabled' do
    member_sources(:authentik).update!(enabled: false)

    assert_nothing_raised do
      Authentik::GroupSyncJob.perform_now
    end
  end

  # ─── GoogleSheets::SyncJob ─────────────────────────────────────

  test 'GoogleSheets::SyncJob skips when sheet source is disabled' do
    member_sources(:sheet).update!(enabled: false)

    assert_nothing_raised do
      GoogleSheets::SyncJob.perform_now
    end
  end

  # ─── Slack::UserSyncJob ────────────────────────────────────────

  test 'Slack::UserSyncJob skips when slack source is disabled' do
    member_sources(:slack).update!(enabled: false)

    assert_nothing_raised do
      Slack::UserSyncJob.perform_now
    end
  end

  # ─── Authentik::FullSyncToAuthentikJob ─────────────────────────

  test 'Authentik::FullSyncToAuthentikJob skips when member_manager source is disabled' do
    member_sources(:member_manager).update!(enabled: false)

    assert_nothing_raised do
      Authentik::FullSyncToAuthentikJob.perform_now
    end
  end

  # ─── Authentik::ApplicationGroupMembershipSyncJob ──────────────

  test 'Authentik::ApplicationGroupMembershipSyncJob skips when member_manager source is disabled' do
    member_sources(:member_manager).update!(enabled: false)

    assert_nothing_raised do
      Authentik::ApplicationGroupMembershipSyncJob.perform_now(%w[sheet slack])
    end
  end
end
