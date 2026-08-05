module Roles
  # Applies a role definition document produced by DefinitionExport.
  #
  # Roles are matched by name, privileges by key, and topics by name, so a document written
  # against one instance applies to another. Nothing in the document can invent a privilege:
  # keys outside the catalog are reported and skipped rather than created, because a privilege
  # the application never checks would be a silent no-op.
  #
  # Modes:
  #   merge   - adds the listed privileges and topic attachments, removes nothing
  #   replace - the listed privileges and topic attachments become exactly what the role has
  #
  # The whole import runs in one transaction: a document with an error changes nothing.
  class DefinitionImport
    MODES = %w[merge replace].freeze
    DEFAULT_MODE = 'merge'.freeze

    # Counts and messages from a run. Warnings describe parts of the document that were
    # skipped; errors mean nothing was written at all.
    class Result
      attr_reader :errors, :warnings
      attr_accessor :roles_created, :roles_updated, :attachments_created, :attachments_removed

      def initialize
        @errors = []
        @warnings = []
        @roles_created = 0
        @roles_updated = 0
        @attachments_created = 0
        @attachments_removed = 0
      end

      def success? = errors.empty?

      def changed? = [roles_created, roles_updated, attachments_created, attachments_removed].sum.positive?

      def summary
        [
          "#{roles_created} role(s) created",
          "#{roles_updated} updated",
          "#{attachments_created} topic attachment(s) added",
          "#{attachments_removed} removed"
        ].join(', ')
      end
    end

    def self.call(...) = new(...).call

    def initialize(document, mode: DEFAULT_MODE, dry_run: false)
      @document = document
      @mode = MODES.include?(mode.to_s) ? mode.to_s : DEFAULT_MODE
      @dry_run = dry_run
      @result = Result.new
      @retention_warnings = []
    end

    def call
      entries = parse_entries
      return @result unless @result.success?

      apply(entries)
      @result
    end

    private

    attr_reader :result

    def replace? = @mode == 'replace'

    def apply(entries)
      Role.transaction do
        entries.each_with_index { |entry, index| import_role(entry, index) }
        raise ActiveRecord::Rollback if @dry_run || !result.success?
      end

      result.warnings.concat(@retention_warnings) if result.success?
    rescue ActiveRecord::RecordInvalid => e
      result.errors << "Could not save: #{e.record.errors.full_messages.join(', ')}"
    end

    # Records something the import deliberately kept rather than removed. Held back until the
    # run finishes without errors: an error anywhere rolls the whole document back, and a note
    # about what was left in place would then describe a partial apply that never happened.
    def warn_retained(message)
      @retention_warnings << message
    end

    def parse_entries
      document = @document.is_a?(String) ? parse_json(@document) : @document
      return [] unless result.success?

      case document
      when Array then document
      when Hash then parse_wrapper(document.with_indifferent_access)
      else
        result.errors << 'Expected a JSON object with a "roles" array.'
        []
      end
    end

    def parse_json(text)
      if text.to_s.strip.empty?
        result.errors << 'No JSON provided.'
        return nil
      end

      JSON.parse(text)
    rescue JSON::ParserError => e
      result.errors << "Could not parse JSON: #{e.message}"
      nil
    end

    def parse_wrapper(document)
      format = document[:format]
      if format.present? && [DefinitionExport::FORMAT, DefinitionExport::LEGACY_FORMAT].exclude?(format)
        result.errors << "Unrecognized document format '#{format}'."
        return []
      end

      version = document[:version]
      if version.present? && version.to_i > DefinitionExport::VERSION
        result.errors << "Document version #{version} is newer than this application understands."
        return []
      end

      roles = document[:roles]
      unless roles.is_a?(Array)
        result.errors << 'Expected a JSON object with a "roles" array.'
        return []
      end

      roles
    end

    def import_role(entry, index)
      unless entry.is_a?(Hash)
        result.errors << "Role ##{index + 1} is not a JSON object."
        return
      end

      entry = entry.with_indifferent_access
      name = entry[:name].to_s.strip
      if name.empty?
        result.errors << "Role ##{index + 1} is missing a name."
        return
      end

      role = find_or_build_role(name)
      created = role.new_record?
      changed = apply_role_attributes(role, entry)

      count_role(created: created, changed: changed)
      apply_topics(role, entry[:topics]) if entry.key?(:topics)
    end

    def find_or_build_role(name)
      Role.where('LOWER(name) = ?', name.downcase).first || Role.new(name: name)
    end

    # Returns whether an existing role was actually altered, so re-applying the same document
    # reports no changes.
    def apply_role_attributes(role, entry)
      keys_before = role.new_record? ? [] : role.privileges.map(&:key).sort

      role.description = entry[:description] if entry.key?(:description)
      attributes_changed = role.changed?
      role.privileges = resolve_privileges(role, entry[:privileges], entry[:name]) if entry.key?(:privileges)
      role.save!

      attributes_changed || role.privileges.reload.map(&:key).sort != keys_before
    end

    def count_role(created:, changed:)
      if created
        result.roles_created += 1
      elsif changed
        result.roles_updated += 1
      end
    end

    # Replace mode may only drop privileges when every key was understood, for the same reason it
    # only prunes topic attachments against a list that fully resolved: an unrecognized key may be
    # a misspelling of one the role holds, and dropping it would revoke access nobody asked to end.
    def resolve_privileges(role, keys, role_name)
      keys = Array(keys).map { |key| key.to_s.strip }.reject(&:empty?)
      found = Privilege.where(key: keys).to_a
      missing = keys - found.map(&:key)
      missing.each { |key| result.warnings << "Role '#{role_name}': unknown privilege '#{key}' skipped." }

      return found if role.new_record? || (replace? && missing.empty?)

      if replace?
        warn_retained("Role '#{role_name}': privileges it already holds left in place because " \
                      'part of the list could not be read.')
      end

      role.privileges.to_a | found
    end

    def apply_topics(role, topics)
      listed = topics.is_a?(Array) ? topics : [topics].compact
      resolved = listed.map { |topic| resolve_topic(role, topic) }
      wanted = resolved.compact
      wanted.each { |attributes| attach_topic(role, **attributes) }

      detach_unlisted_topics(role, wanted) if replace? && detachable?(role, resolved)
    end

    # Replace mode may only prune attachments when every entry was understood. A name that did
    # not resolve might have been the one naming an attachment the role already holds — under a
    # spelling this instance does not use — and pruning against a partial list would delete it.
    def detachable?(role, resolved)
      return true if resolved.all?

      warn_retained("Role '#{role.name}': existing topic attachments left in place because " \
                    'part of the list could not be read.')
      false
    end

    # A topic entry is either a bare name or an object naming the topic and the population
    # ("trained in" or "can train") the role is conferred to.
    def resolve_topic(role, entry)
      entry = { 'name' => entry } if entry.is_a?(String)
      unless entry.is_a?(Hash)
        result.errors << "Role '#{role.name}': topic entries must be a name or an object."
        return nil
      end

      entry = entry.with_indifferent_access
      name = entry[:name].to_s.strip
      source = entry[:member_source].presence || 'trained_in'

      unless TrainingTopicRole::MEMBER_SOURCES.include?(source)
        result.errors << "Role '#{role.name}': '#{source}' is not a valid member source."
        return nil
      end

      topic = TrainingTopic.where('LOWER(name) = ?', name.downcase).first
      if topic.nil?
        result.warnings << "Role '#{role.name}': no training topic named '#{name}', attachment skipped."
        return nil
      end

      { topic: topic, member_source: source }
    end

    def attach_topic(role, topic:, member_source:)
      attachment = TrainingTopicRole.find_or_initialize_by(role: role, training_topic: topic,
                                                           member_source: member_source)
      return unless attachment.new_record?

      attachment.save!
      result.attachments_created += 1
    end

    def detach_unlisted_topics(role, wanted)
      keep = wanted.map { |attributes| [attributes[:topic].id, attributes[:member_source]] }
      role.topic_roles.reload.each do |attachment|
        next if keep.include?([attachment.training_topic_id, attachment.member_source])

        attachment.destroy!
        result.attachments_removed += 1
      end
    end
  end
end
