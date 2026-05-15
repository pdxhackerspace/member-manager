class AddDefaultLocalityToDefaultSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :default_settings, :map_default_city, :string, null: false, default: 'Portland'
    add_column :default_settings, :map_default_state, :string, null: false, default: 'Oregon'
  end
end
