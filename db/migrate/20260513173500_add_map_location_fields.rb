class AddMapLocationFields < ActiveRecord::Migration[8.1]
  def change
    change_table :default_settings, bulk: true do |t|
      t.decimal :map_center_latitude, precision: 10, scale: 6, null: false, default: 45.581678
      t.decimal :map_center_longitude, precision: 10, scale: 6, null: false, default: -122.682156
      t.decimal :map_radius_miles, precision: 5, scale: 2, null: false, default: 4.0
    end

    change_table :users, bulk: true do |t|
      t.decimal :mailing_latitude, precision: 10, scale: 6
      t.decimal :mailing_longitude, precision: 10, scale: 6
      t.datetime :mailing_geocoded_at
    end
  end
end
