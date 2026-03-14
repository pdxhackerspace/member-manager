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
end
