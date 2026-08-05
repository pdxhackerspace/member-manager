class RenameMemberManagerSystemApplication < ActiveRecord::Migration[8.1]
  OLD_NAME = 'Member Manager'.freeze
  NEW_NAME = 'Member Zone'.freeze

  # Authentik::CoreGroupProvisioner finds the application holding every core and training
  # group by name, so the row has to follow the rename or the provisioner builds a second
  # application and orphans the existing groups.
  def up
    rename_application(from: OLD_NAME, to: NEW_NAME)
  end

  def down
    rename_application(from: NEW_NAME, to: OLD_NAME)
  end

  private

  # applications.name has no unique index. Renaming while a row already holds the target
  # name would leave two applications answering to it, so leave the data alone in that case
  # and let an operator merge them.
  def rename_application(from:, to:)
    return if select_value("SELECT 1 FROM applications WHERE name = '#{to}' LIMIT 1").present?

    execute("UPDATE applications SET name = '#{to}' WHERE name = '#{from}'")
  end
end
