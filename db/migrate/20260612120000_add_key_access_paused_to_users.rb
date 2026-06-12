class AddKeyAccessPausedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :key_access_paused, :boolean, default: false, null: false
    add_column :users, :key_access_paused_at, :datetime
    add_index :users, :key_access_paused
  end
end
