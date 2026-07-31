require 'test_helper'

module Roles
  class DefinitionExportTest < ActiveSupport::TestCase
    setup do
      Privilege.seed_defaults!
      @topic = training_topics(:laser_cutting)
    end

    test 'exports roles with their privilege keys and topic attachments' do
      role = Role.create!(name: 'Fob team', description: 'Handles fobs',
                          privileges: Privilege.where(key: %w[access.manage_rfids access.view_rfids]))
      TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'can_train')

      document = DefinitionExport.call
      exported = document[:roles].find { |entry| entry[:name] == 'Fob team' }

      assert_equal DefinitionExport::FORMAT, document[:format]
      assert_equal 'Handles fobs', exported[:description]
      assert_equal %w[access.manage_rfids access.view_rfids], exported[:privileges]
      assert_equal [{ name: @topic.name, member_source: 'can_train' }], exported[:topics]
    end

    test 'exports a role with no privileges or topics as empty lists' do
      Role.create!(name: 'Empty')

      exported = DefinitionExport.call[:roles].find { |entry| entry[:name] == 'Empty' }

      assert_empty exported[:privileges]
      assert_empty exported[:topics]
    end

    test 'limits the export to a given scope' do
      Role.create!(name: 'Included')
      Role.create!(name: 'Excluded')

      document = DefinitionExport.call(roles: Role.where(name: 'Included'))

      assert_equal ['Included'], document[:roles].pluck(:name)
    end

    test 'to_json produces a document the importer accepts' do
      role = Role.create!(name: 'Round trip', privileges: Privilege.where(key: 'payments.view'))
      TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'trained_in')
      json = DefinitionExport.new(roles: Role.where(id: role.id)).to_json
      role.destroy!

      result = DefinitionImport.call(json, mode: 'replace')

      assert_predicate result, :success?
      restored = Role.find_by!(name: 'Round trip')
      assert_equal ['payments.view'], restored.privilege_keys
      assert_equal [@topic.id], restored.topic_roles.map(&:training_topic_id)
    end
  end
end
