require 'test_helper'

# A privilege that nothing references is a promise the roles editor makes and the
# application does not keep: a director grants it, the holder sees "You do not have access
# to that section", and the roles system stops being trusted. That was true of twenty keys
# before the rollout and is true of none now.
#
# This test is deliberately crude — it asks whether the key appears anywhere in app/ or
# lib/, not whether it appears in the right place. A finer check would have to model what
# "enforced" means, and every version of that is easier to satisfy accidentally than this
# one. Adding a key to the catalog and nothing else fails here, which is the point.
class PrivilegeCatalogCoverageTest < ActiveSupport::TestCase
  # The catalog itself and the seeded roles that hand keys out are where every key appears
  # by definition, so neither counts as a reference.
  DECLARATION_FILES = %w[app/models/privilege.rb app/models/role.rb].freeze

  SEARCH_ROOTS = %w[app lib].freeze

  test 'every catalog key is referenced by something that could enforce it' do
    orphans = Privilege::CATALOG.map { |entry| entry[:key] }.reject { |key| referenced?(key) }

    assert_empty orphans.sort,
                 'these privileges can be granted but nothing anywhere reads them — ' \
                 'either enforce the key or remove it from the catalog'
  end

  test 'every seeded role hands out keys that exist' do
    unknown = Role::DEFAULT_ROLES.flat_map do |role|
      (role[:privileges] - Privilege::CATALOG.pluck(:key).map(&:to_s)).map { |key| "#{role[:name]}: #{key}" }
    end

    assert_empty unknown.sort
  end

  test 'no seeded role is empty' do
    hollow = Role::DEFAULT_ROLES.select { |role| role[:privileges].blank? }.pluck(:name)

    assert_empty hollow, 'a role conferring nothing looks identical to a broken one'
  end

  # Guards the test above: if the search ever stops finding anything, every key would pass
  # for the wrong reason.
  test 'the search actually reads the source tree' do
    assert referenced?('members.view_list')
    assert_not referenced?('members.view_list.not_a_real_key')
  end

  private

  def referenced?(key)
    source_files.any? { |path| File.read(path).include?(key) }
  end

  def source_files
    @source_files ||= SEARCH_ROOTS
                      .flat_map { |root| Rails.root.glob("#{root}/**/*.{rb,erb,rake}") }
                      .reject { |path| DECLARATION_FILES.any? { |name| path.to_s.end_with?(name) } }
  end
end
