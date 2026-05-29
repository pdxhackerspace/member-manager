module Authentik
  class UserSync
    # Fields that can be synced to Authentik
    SYNCABLE_FIELDS = %w[email full_name username active].freeze

    # User fields stored in Authentik's attributes JSON (not top-level user fields)
    ATTRIBUTE_SYNC_FIELDS = %w[slack_id slack_handle trained_on can_train].freeze

    # Mapping from MemberManager field names to Authentik field names
    FIELD_MAPPING = {
      'email' => 'email',
      'full_name' => 'name',
      'username' => 'username',
      'active' => 'is_active'
    }.freeze

    attr_reader :user, :client

    def initialize(user, client: nil)
      @user = user
      @client = client || Authentik::Client.new
    end

    # Push user changes to Authentik
    def sync_to_authentik!(changed_fields: nil)
      return { status: 'skipped', reason: 'no_authentik_id' } if user.authentik_id.blank?
      return { status: 'skipped', reason: 'api_not_configured' } unless api_configured?

      fields_to_sync = syncable_fields_for(changed_fields)
      attribute_fields_to_sync = attribute_fields_for(changed_fields)
      if fields_to_sync.empty? && attribute_fields_to_sync.empty? && changed_fields.present?
        return { status: 'skipped', reason: 'no_syncable_changes' }
      end

      synced_fields = fields_to_sync + attribute_fields_to_sync
      Rails.logger.info(
        "[Authentik::UserSync] Syncing user #{user.id} " \
        "(#{user.authentik_id}) to Authentik: #{synced_fields.join(', ')}"
      )

      begin
        client.update_user(user.authentik_id, **build_update_payload(fields_to_sync))
        user.update_columns(last_synced_at: Time.current, authentik_dirty: false)

        Rails.logger.info("[Authentik::UserSync] Successfully synced user #{user.id} to Authentik")
        { status: 'synced', authentik_id: user.authentik_id, fields: synced_fields }
      rescue StandardError => e
        Rails.logger.error("[Authentik::UserSync] Failed to sync user to Authentik: #{e.message}")
        { status: 'error', error: e.message }
      end
    end

    # Pull user changes from Authentik
    def sync_from_authentik!
      return { status: 'skipped', reason: 'no_authentik_id' } if user.authentik_id.blank?
      return { status: 'skipped', reason: 'api_not_configured' } unless api_configured?

      Rails.logger.info("[Authentik::UserSync] Fetching user #{user.id} (#{user.authentik_id}) from Authentik")

      begin
        authentik_data = client.get_user(user.authentik_id)
        record_authentik_data(authentik_data)
      rescue StandardError => e
        Rails.logger.error("[Authentik::UserSync] Failed to fetch user from Authentik: #{e.message}")
        { status: 'error', error: e.message }
      end
    end

    # Store Authentik data locally without copying profile fields onto the User record.
    def apply_authentik_data(authentik_data, skip_if_no_changes: true)
      record_authentik_data(authentik_data, skip_if_no_changes: skip_if_no_changes)
    end

    # Class method for batch sync of all users with Authentik IDs
    def self.sync_all_to_authentik!
      results = { synced: 0, skipped: 0, errors: 0 }

      User.where.not(authentik_id: [nil, '']).find_each do |user|
        result = new(user).sync_to_authentik!
        case result[:status]
        when 'synced' then results[:synced] += 1
        when 'skipped' then results[:skipped] += 1
        when 'error' then results[:errors] += 1
        end
      end

      results
    end

    private

    def api_configured?
      AuthentikConfig.settings.api_token.present? && AuthentikConfig.settings.api_base_url.present?
    end

    def syncable_fields_for(changed_fields)
      return SYNCABLE_FIELDS if changed_fields.blank?

      changed_fields & SYNCABLE_FIELDS
    end

    def attribute_fields_for(changed_fields)
      return ATTRIBUTE_SYNC_FIELDS if changed_fields.blank?

      changed_fields & ATTRIBUTE_SYNC_FIELDS
    end

    def build_update_payload(fields_to_sync)
      attrs = fields_to_sync.index_with { |field| user.send(field) }
                            .transform_keys { |field| FIELD_MAPPING[field] }
      attrs[:attributes] = UserAttributes.for(user)
      attrs
    end

    def record_authentik_data(authentik_data, skip_if_no_changes: true)
      authentik_user = AuthentikUser.find_or_initialize_by(authentik_id: user.authentik_id)
      previous_attributes = authentik_user.attributes.slice('username', 'email', 'full_name', 'is_active')

      authentik_user.assign_attributes(
        username: authentik_data['username'],
        email: authentik_data['email'],
        full_name: authentik_data['name'],
        is_active: authentik_data['is_active'] != false,
        raw_attributes: authentik_data,
        last_synced_at: Time.current,
        user: user
      )

      current_attributes = authentik_user.attributes.slice('username', 'email', 'full_name', 'is_active')
      changes = current_attributes.filter_map do |field, value|
        field if previous_attributes[field] != value
      end

      return { status: 'no_changes' } if changes.empty? && skip_if_no_changes && authentik_user.persisted?

      authentik_user.save!

      { status: 'updated', changes: changes }
    rescue StandardError => e
      Rails.logger.error("[Authentik::UserSync] Failed to record Authentik data: #{e.message}")
      { status: 'error', error: e.message }
    end
  end
end
