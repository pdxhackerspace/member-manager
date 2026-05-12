class AddRfidFacilityCodeToDefaultSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :default_settings, :rfid_facility_code, :integer
  end
end
