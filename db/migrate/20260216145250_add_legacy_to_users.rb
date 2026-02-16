class AddLegacyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :legacy, :boolean, default: false, null: false
    add_index :users, :legacy
  end
end
