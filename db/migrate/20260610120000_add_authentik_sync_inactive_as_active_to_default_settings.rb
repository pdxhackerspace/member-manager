class AddAuthentikSyncInactiveAsActiveToDefaultSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :default_settings, :authentik_sync_inactive_as_active, :boolean, default: true, null: false
  end
end
