class RenameMemberManagerSourceKeyToMemberZone < ActiveRecord::Migration[8.1]
  OLD_KEY = 'member_manager'.freeze
  NEW_KEY = 'member_zone'.freeze

  def up
    rename_source_key(from: OLD_KEY, to: NEW_KEY)
    execute(<<~SQL.squish)
      UPDATE member_sources SET name = 'Member Zone' WHERE key = '#{NEW_KEY}' AND name = 'Member Manager'
    SQL
  end

  def down
    rename_source_key(from: NEW_KEY, to: OLD_KEY)
    execute(<<~SQL.squish)
      UPDATE member_sources SET name = 'Member Manager' WHERE key = '#{OLD_KEY}' AND name = 'Member Zone'
    SQL
  end

  private

  # member_sources.key is uniquely indexed, so a row already sitting on the target key
  # (from a partially applied run) has to go before the rename can land.
  def rename_source_key(from:, to:)
    execute("DELETE FROM member_sources WHERE key = '#{to}'") if key_exists?(from) && key_exists?(to)
    execute("UPDATE member_sources SET key = '#{to}' WHERE key = '#{from}'")
  end

  def key_exists?(key)
    select_value("SELECT 1 FROM member_sources WHERE key = '#{key}' LIMIT 1").present?
  end
end
