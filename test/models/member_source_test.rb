require 'test_helper'

class MemberSourceTest < ActiveSupport::TestCase
  test 'enabled? returns true for an enabled source' do
    assert MemberSource.enabled?('authentik')
  end

  test 'enabled? returns false for a disabled source' do
    member_sources(:authentik).update!(enabled: false)

    assert_not MemberSource.enabled?('authentik')
  end

  test 'enabled? returns true for a nonexistent key' do
    assert MemberSource.enabled?('nonexistent')
  end

  test 'enabled? reflects toggle' do
    source = member_sources(:sheet)
    assert MemberSource.enabled?('sheet')

    source.update!(enabled: false)
    assert_not MemberSource.enabled?('sheet')

    source.update!(enabled: true)
    assert MemberSource.enabled?('sheet')
  end

  test 'validates key uniqueness' do
    duplicate = MemberSource.new(key: 'authentik', name: 'Dupe')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], 'has already been taken'
  end

  test 'validates key inclusion' do
    bad = MemberSource.new(key: 'invalid_key', name: 'Bad')

    assert_not bad.valid?
    assert_includes bad.errors[:key], 'is not included in the list'
  end

  test 'enabled scope returns only enabled sources' do
    member_sources(:slack).update!(enabled: false)

    enabled_keys = MemberSource.enabled.pluck(:key)
    assert_includes enabled_keys, 'authentik'
    assert_not_includes enabled_keys, 'slack'
  end

  test 'record_sync! clears error state and marks healthy' do
    source = member_sources(:authentik)
    source.update!(
      sync_status: 'failing',
      consecutive_error_count: 3,
      last_error_message: 'previous failure'
    )

    source.record_sync!

    source.reload
    assert_equal 'healthy', source.sync_status
    assert_equal 0, source.consecutive_error_count
    assert_nil source.last_error_message
    assert source.last_successful_sync_at.present?
  end

  test 'record_failed_sync! increments errors and sets degraded then failing' do
    source = member_sources(:sheet)
    source.update!(sync_status: 'healthy', consecutive_error_count: 0, last_error_message: nil)

    source.record_failed_sync!('first')
    source.reload
    assert_equal 'degraded', source.sync_status
    assert_equal 1, source.consecutive_error_count

    source.record_failed_sync!('second')
    source.reload
    assert_equal 'degraded', source.sync_status
    assert_equal 2, source.consecutive_error_count

    source.record_failed_sync!('third')
    source.reload
    assert_equal 'failing', source.sync_status
    assert_equal 3, source.consecutive_error_count
    assert_match(/third/, source.last_error_message)
  end

  test 'seed_defaults adopts pre-rename member_zone source key' do
    MemberSource.where(key: [MemberSource::MEMBER_ZONE_KEY, MemberSource::MEMBER_ZONE_LEGACY_KEY]).delete_all
    legacy = MemberSource.create!(
      key: MemberSource::MEMBER_ZONE_KEY,
      name: 'Member Manager',
      display_order: 2
    )
    legacy.update_column(:key, MemberSource::MEMBER_ZONE_LEGACY_KEY)

    assert_no_difference -> { MemberSource.count } do
      MemberSource.seed_defaults!
    end

    legacy.reload
    assert_equal MemberSource::MEMBER_ZONE_KEY, legacy.key
    assert_equal 'Member Zone', legacy.name
  end

  test 'a disabled pre-rename member_zone source is read as disabled' do
    as_legacy_member_zone_source(enabled: false)

    assert_not MemberSource.enabled?(MemberSource::MEMBER_ZONE_KEY)
    assert_not MemberSource.enabled?(MemberSource::MEMBER_ZONE_LEGACY_KEY)
  end

  test 'an enabled pre-rename member_zone source is read as enabled' do
    as_legacy_member_zone_source(enabled: true)

    assert MemberSource.enabled?(MemberSource::MEMBER_ZONE_KEY)
  end

  test 'the canonical member_zone row wins when both spellings exist' do
    as_legacy_member_zone_source(enabled: true)
    MemberSource.create!(key: MemberSource::MEMBER_ZONE_KEY, name: 'Member Zone',
                         display_order: 2, enabled: false)

    assert_not MemberSource.enabled?(MemberSource::MEMBER_ZONE_KEY)
  end

  test 'for does not add a second row when only the pre-rename key exists' do
    as_legacy_member_zone_source(enabled: true)

    assert_no_difference -> { MemberSource.count } do
      assert_equal MemberSource::MEMBER_ZONE_LEGACY_KEY, MemberSource.for(MemberSource::MEMBER_ZONE_KEY).key
    end
  end

  # Every one of these goes through update!, which the key validation would reject if it
  # did not make room for rows that predate the rename.
  test 'a pre-rename row still refreshes local statistics' do
    source = as_legacy_member_zone_source(enabled: true)
    source.update_column(:entry_count, 0)

    source.refresh_statistics!

    assert_equal User.count, source.reload.entry_count
  end

  test 'a pre-rename row still records a sync' do
    source = as_legacy_member_zone_source(enabled: true)

    source.record_sync!

    assert_equal 'healthy', source.reload.sync_status
  end

  test 'a new source cannot be created under the pre-rename key' do
    MemberSource.where(key: [MemberSource::MEMBER_ZONE_KEY, MemberSource::MEMBER_ZONE_LEGACY_KEY]).delete_all
    source = MemberSource.new(key: MemberSource::MEMBER_ZONE_LEGACY_KEY, name: 'Member Manager')

    assert_not source.valid?
    assert_includes source.errors[:key], 'is not included in the list'
  end

  private

  # Replaces the member_zone fixture with a row spelled the pre-rename way, as a database
  # written before the rename would have it.
  def as_legacy_member_zone_source(enabled:)
    MemberSource.where(key: [MemberSource::MEMBER_ZONE_KEY, MemberSource::MEMBER_ZONE_LEGACY_KEY]).delete_all
    source = MemberSource.create!(key: MemberSource::MEMBER_ZONE_KEY, name: 'Member Manager',
                                  display_order: 2, enabled: enabled)
    source.update_column(:key, MemberSource::MEMBER_ZONE_LEGACY_KEY)
    source.reload
  end
end
