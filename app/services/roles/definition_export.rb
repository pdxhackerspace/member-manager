module Roles
  # Serializes roles to the portable JSON document that DefinitionImport reads back.
  #
  # Everything is keyed by name or privilege key rather than by database id, so a document
  # exported from one instance applies cleanly to another with different id sequences.
  class DefinitionExport
    FORMAT = 'member-zone.role-definitions'.freeze
    # Pre-rename value of FORMAT. Still accepted on import so documents exported
    # before the Member Zone rename keep applying.
    LEGACY_FORMAT = 'member-manager.role-definitions'.freeze
    VERSION = 1

    def self.call(...) = new(...).call

    def initialize(roles: nil)
      @roles = roles
    end

    def call
      {
        format: FORMAT,
        version: VERSION,
        exported_at: Time.current.utc.iso8601,
        roles: scope.map { |role| role_document(role) }
      }
    end

    def to_json(*_args)
      JSON.pretty_generate(call.deep_stringify_keys)
    end

    private

    def scope
      (@roles || Role.all).includes(:privileges, topic_roles: :training_topic).order(:name)
    end

    def role_document(role)
      {
        name: role.name,
        description: role.description,
        privileges: role.privileges.map(&:key).sort,
        topics: role.topic_roles.sort_by { |topic_role| [topic_role.training_topic.name, topic_role.member_source] }
                    .map { |topic_role| topic_document(topic_role) }
      }
    end

    def topic_document(topic_role)
      { name: topic_role.training_topic.name, member_source: topic_role.member_source }
    end
  end
end
