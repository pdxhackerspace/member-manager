require 'test_helper'

module Roles
  class DefinitionImportTest < ActiveSupport::TestCase
    setup do
      Privilege.seed_defaults!
      @topic = training_topics(:laser_cutting)
    end

    test 'creates a role with privileges and a topic attachment' do
      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]))

      assert_predicate result, :success?
      assert_equal 1, result.roles_created
      assert_equal 1, result.attachments_created

      role = Role.find_by!(name: 'Fob team')
      assert_equal ['access.manage_rfids'], role.privilege_keys
      attached = role.topic_roles.map { |attachment| [attachment.training_topic_id, attachment.member_source] }
      assert_equal [[@topic.id, 'trained_in']], attached
    end

    test 'matches an existing role by name regardless of case' do
      Role.create!(name: 'FOB TEAM')

      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]))

      assert_equal 0, result.roles_created
      assert_equal 1, result.roles_updated
      assert_equal ['access.manage_rfids'], Role.find_by!(name: 'FOB TEAM').privilege_keys
    end

    test 'merge mode adds privileges without removing the ones already held' do
      role = Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))

      DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), mode: 'merge')

      assert_equal %w[access.manage_rfids payments.view], role.reload.privilege_keys.sort
    end

    test 'replace mode makes the listed privileges the whole bundle' do
      role = Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))

      DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), mode: 'replace')

      assert_equal ['access.manage_rfids'], role.reload.privilege_keys
    end

    test 'replace mode keeps the privileges a role holds when a key does not resolve' do
      role = Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))

      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids nonsense.key])]),
                                     mode: 'replace')

      assert_predicate result, :success?
      assert_equal %w[access.manage_rfids payments.view], role.reload.privilege_keys.sort
      assert(result.warnings.any? { |warning| warning.include?('left in place') })
    end

    test 'merge mode leaves topic attachments the document omits alone' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')

      result = DefinitionImport.call(document([role_entry]), mode: 'merge')

      assert_equal 0, result.attachments_removed
      assert_equal 2, role.topic_roles.reload.count
    end

    test 'replace mode detaches topics the document omits' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')

      result = DefinitionImport.call(document([role_entry]), mode: 'replace')

      assert_equal 1, result.attachments_removed
      assert_equal [@topic.id], role.topic_roles.reload.map(&:training_topic_id)
    end

    test 'replace mode keeps an attachment whose topic name the file spells differently' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')

      result = DefinitionImport.call(document([role_entry(topics: ['Wood Working'])]), mode: 'replace')

      assert_predicate result, :success?
      assert_equal 0, result.attachments_removed
      assert_equal [training_topics(:woodworking).id], role.topic_roles.reload.map(&:training_topic_id)
    end

    test 'replace mode reports that it left attachments alone after an unresolved topic' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')

      result = DefinitionImport.call(document([role_entry(topics: [@topic.name, 'Nowhere'])]), mode: 'replace')

      assert_equal 1, result.attachments_created
      assert_equal 0, result.attachments_removed
      assert_equal [@topic.id, training_topics(:woodworking).id].sort,
                   role.topic_roles.reload.map(&:training_topic_id).sort
      assert(result.warnings.any? { |warning| warning.include?('left in place') })
    end

    test 'a topic entry that fails outright is not reported as attachments left in place' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')
      topics = [@topic.name, { 'name' => @topic.name, 'member_source' => 'everyone' }]

      result = DefinitionImport.call(document([role_entry(topics: topics)]), mode: 'replace')

      assert_not_predicate result, :success?
      assert_empty result.warnings.grep(/left in place/)
      assert_equal [training_topics(:woodworking).id], role.topic_roles.reload.map(&:training_topic_id)
    end

    test 'an error in a later role withdraws what an earlier role reported leaving in place' do
      Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))
      entries = [role_entry(privileges: %w[nonsense.key], topics: ['Nowhere']), { 'name' => ' ' }]

      result = DefinitionImport.call(document(entries), mode: 'replace')

      assert_not_predicate result, :success?
      assert_empty result.warnings.grep(/left in place/)
      assert(result.warnings.any? { |warning| warning.include?("unknown privilege 'nonsense.key'") })
    end

    test 'a dry run still reports what it would leave in place' do
      role = Role.create!(name: 'Fob team')
      TrainingTopicRole.create!(training_topic: training_topics(:woodworking), role: role,
                                member_source: 'trained_in')

      result = DefinitionImport.call(document([role_entry(topics: [@topic.name, 'Nowhere'])]),
                                     mode: 'replace', dry_run: true)

      assert_predicate result, :success?
      assert(result.warnings.any? { |warning| warning.include?('left in place') })
    end

    test 'a topic entry may name the population the role is conferred to' do
      DefinitionImport.call(document([role_entry(topics: [{ 'name' => @topic.name,
                                                            'member_source' => 'can_train' }])]))

      assert_predicate TrainingTopicRole.find_by(role: Role.find_by(name: 'Fob team')), :can_train?
    end

    test 'a bare topic name defaults to conferring on training' do
      DefinitionImport.call(document([role_entry(topics: [@topic.name])]))

      assert_predicate TrainingTopicRole.find_by(role: Role.find_by(name: 'Fob team')), :trained_in?
    end

    test 'privileges outside the catalog are skipped with a warning' do
      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids nonsense.key])]))

      assert_predicate result, :success?
      assert_equal ['access.manage_rfids'], Role.find_by!(name: 'Fob team').privilege_keys
      assert_match "unknown privilege 'nonsense.key'", result.warnings.first
      assert_nil Privilege.find_by(key: 'nonsense.key')
    end

    test 'a topic the instance does not have is skipped with a warning' do
      result = DefinitionImport.call(document([role_entry(topics: ['Nowhere'])]))

      assert_predicate result, :success?
      assert_equal 0, result.attachments_created
      assert_match "no training topic named 'Nowhere'", result.warnings.first
    end

    test 'an invalid member source fails the whole import' do
      result = DefinitionImport.call(document([role_entry(topics: [{ 'name' => @topic.name,
                                                                     'member_source' => 'everyone' }])]))

      assert_not_predicate result, :success?
      assert_nil Role.find_by(name: 'Fob team')
    end

    test 'a role without a name fails the import and writes nothing' do
      entries = [role_entry, { 'name' => ' ', 'privileges' => [] }]

      result = DefinitionImport.call(document(entries))

      assert_not_predicate result, :success?
      assert_match 'missing a name', result.errors.first
      assert_nil Role.find_by(name: 'Fob team')
    end

    test 'unparseable JSON is reported rather than raised' do
      result = DefinitionImport.call('{ not json')

      assert_not_predicate result, :success?
      assert_match 'Could not parse JSON', result.errors.first
    end

    test 'a document without a roles array is rejected' do
      result = DefinitionImport.call({ 'format' => DefinitionExport::FORMAT }.to_json)

      assert_not_predicate result, :success?
      assert_match 'roles', result.errors.first
    end

    test 'a document from another application is rejected' do
      result = DefinitionImport.call({ 'format' => 'something-else', 'roles' => [] }.to_json)

      assert_not_predicate result, :success?
      assert_match 'Unrecognized document format', result.errors.first
    end

    test 'a document from a newer version is rejected' do
      result = DefinitionImport.call({ 'format' => DefinitionExport::FORMAT,
                                       'version' => DefinitionExport::VERSION + 1, 'roles' => [] }.to_json)

      assert_not_predicate result, :success?
      assert_match 'newer than this application understands', result.errors.first
    end

    test 'a bare array of roles is accepted' do
      result = DefinitionImport.call([role_entry].to_json)

      assert_predicate result, :success?
      assert_equal 1, result.roles_created
    end

    test 'a dry run reports what would change without writing it' do
      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), dry_run: true)

      assert_predicate result, :success?
      assert_equal 1, result.roles_created
      assert_equal 1, result.attachments_created
      assert_nil Role.find_by(name: 'Fob team')
    end

    test 're-applying the same document reports nothing changed' do
      DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), mode: 'replace')

      result = DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), mode: 'replace')

      assert_not_predicate result, :changed?
    end

    test 'an unrecognized mode falls back to merge' do
      role = Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))

      DefinitionImport.call(document([role_entry(privileges: %w[access.manage_rfids])]), mode: 'obliterate')

      assert_includes role.reload.privilege_keys, 'payments.view'
    end

    test 'a role entry omitting privileges leaves the bundle untouched' do
      role = Role.create!(name: 'Fob team', privileges: Privilege.where(key: 'payments.view'))

      DefinitionImport.call(document([{ 'name' => 'Fob team', 'description' => 'Renamed purpose' }]),
                            mode: 'replace')

      assert_equal ['payments.view'], role.reload.privilege_keys
      assert_equal 'Renamed purpose', role.description
    end

    private

    def document(entries)
      { 'format' => DefinitionExport::FORMAT, 'version' => DefinitionExport::VERSION,
        'roles' => entries }.to_json
    end

    def role_entry(privileges: [], topics: nil)
      { 'name' => 'Fob team', 'description' => 'Handles fobs', 'privileges' => privileges,
        'topics' => topics || [{ 'name' => @topic.name, 'member_source' => 'trained_in' }] }
    end
  end
end
