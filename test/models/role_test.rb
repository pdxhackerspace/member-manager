require 'test_helper'

class RoleTest < ActiveSupport::TestCase
  setup do
    Privilege.seed_defaults!
  end

  test 'seeding creates the starter roles with their privileges' do
    Role.seed_defaults!

    approver = Role.find_by(name: 'Application approver')

    assert_includes approver.privilege_keys, 'applications.approve'
    assert_includes approver.privilege_keys, 'training.grant_trainer'
  end

  test 'seeding is idempotent and does not overwrite edits' do
    Role.seed_defaults!
    curator = Role.find_by(name: 'Topic curator')
    curator.privileges = Privilege.where(key: 'training.documents.manage')

    Role.seed_defaults!

    assert_equal ['training.documents.manage'], curator.reload.privilege_keys
    assert_equal Role::DEFAULT_ROLES.size, Role.count
  end

  test 'every seeded privilege key exists in the catalog' do
    catalog_keys = Privilege::CATALOG.pluck(:key)
    role_keys = Role::DEFAULT_ROLES.flat_map { |attrs| attrs[:privileges] }.uniq

    assert_empty role_keys - catalog_keys
  end

  test 'topic curator carries only topic scoped privileges' do
    Role.seed_defaults!

    curator = Role.find_by(name: 'Topic curator')

    assert curator.privileges.all?(&:topic_scoped?)
  end

  test 'names are unique regardless of case' do
    Role.create!(name: 'Duplicate role')
    duplicate = Role.new(name: 'duplicate role')

    assert_not duplicate.valid?
  end
end
