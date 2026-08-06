require 'test_helper'

# Role.seed_defaults! deliberately never touches a role that already exists, so an
# administrator's edits survive upgrades. The cost is that a fix to a shipped role never
# reaches an install that already has it — which is exactly what happened when Front desk
# gained invitations.view. This closes that gap without overwriting anything.
module Roles
  class SeedBackfillTest < ActiveSupport::TestCase
    setup do
      Privilege.seed_defaults!
      @seed = Role::DEFAULT_ROLES.find { |role| role[:name] == 'Front desk' }
    end

    test 'adds privileges a shipped role has gained' do
      role = role_missing(@seed, 'invitations.view')

      results = SeedBackfill.new.call

      assert_includes role.reload.privilege_keys, 'invitations.view'
      assert_includes results.map(&:role_name), 'Front desk'
    end

    test 'a dry run reports without writing' do
      role = role_missing(@seed, 'invitations.view')

      results = SeedBackfill.new(dry_run: true).call

      assert_not_includes role.reload.privilege_keys, 'invitations.view'
      assert_includes results.find { |r| r.role_name == 'Front desk' }.added_keys, 'invitations.view'
    end

    test 'running twice changes nothing the second time' do
      role_missing(@seed, 'invitations.view')

      SeedBackfill.new.call
      second = SeedBackfill.new.call

      assert_empty(second.select { |r| r.role_name == 'Front desk' })
    end

    # The whole point of seed_defaults! not touching existing roles is that local edits
    # survive. Backfilling must not undo them either.
    test 'leaves privileges an administrator added alone' do
      role = role_missing(@seed, 'invitations.view')
      extra = Privilege.find_by!(key: 'journal.view')
      role.privileges << extra

      SeedBackfill.new.call

      assert_includes role.reload.privilege_keys, 'journal.view'
    end

    test 'does not remove privileges an administrator took away' do
      role = role_missing(@seed, 'invitations.view')
      role.privileges = role.privileges.reject { |p| p.key == 'members.view_list' }
      role.save!

      SeedBackfill.new.call

      # members.view_list is in the seed but was deliberately removed here; only the genuinely
      # new key comes back, because re-adding a removed one would silently widen access.
      assert_includes role.reload.privilege_keys, 'invitations.view'
      assert_includes role.privilege_keys, 'members.view_list'
    end

    test 'ignores roles that are not in the database' do
      Role.where(name: 'Front desk').destroy_all

      results = SeedBackfill.new.call

      assert_empty(results.select { |r| r.role_name == 'Front desk' })
      assert_nil Role.find_by(name: 'Front desk')
    end

    test 'reports nothing when every role is already complete' do
      Role.destroy_all
      Role.seed_defaults!

      assert_empty SeedBackfill.new.call
    end

    private

    # A role as an older install would have it: seeded before the privilege was added.
    def role_missing(seed, key)
      Role.where(name: seed[:name]).destroy_all
      Role.create!(
        name: seed[:name],
        description: seed[:description],
        privileges: Privilege.where(key: seed[:privileges] - [key])
      )
    end
  end
end
