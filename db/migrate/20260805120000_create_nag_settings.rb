class CreateNagSettings < ActiveRecord::Migration[8.1]
  def up
    create_table :nag_settings do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end

    add_index :nag_settings, :key, unique: true
    add_index :nag_settings, :enabled

    attrs = NagSetting::CATALOG['slack_signup']
    NagSetting.create!(
      key: 'slack_signup',
      name: attrs[:name],
      description: attrs[:description],
      enabled: attrs[:enabled]
    )
  end

  def down
    drop_table :nag_settings
  end
end
