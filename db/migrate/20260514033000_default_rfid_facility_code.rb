class DefaultRfidFacilityCode < ActiveRecord::Migration[8.1]
  def up
    change_column_default :default_settings, :rfid_facility_code, from: nil, to: 127
    DefaultSetting.where(rfid_facility_code: nil).update_all(rfid_facility_code: 127)
    change_column_null :default_settings, :rfid_facility_code, false
  end

  def down
    change_column_null :default_settings, :rfid_facility_code, true
    change_column_default :default_settings, :rfid_facility_code, from: 127, to: nil
  end
end
