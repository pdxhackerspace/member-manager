require 'test_helper'

class DefaultSettingTest < ActiveSupport::TestCase
  test 'rfid facility prefix includes trailing comma when configured' do
    setting = default_settings(:one)
    setting.rfid_facility_code = 127

    assert_equal '127,', setting.rfid_facility_prefix
  end

  test 'rfid facility code is required' do
    setting = default_settings(:one)
    setting.rfid_facility_code = nil

    assert_not setting.valid?
    assert_includes setting.errors[:rfid_facility_code], "can't be blank"
  end

  test 'map defaults require plausible coordinates and radius' do
    setting = default_settings(:one)
    setting.map_center_latitude = 91
    setting.map_center_longitude = -181
    setting.map_radius_miles = 0

    assert_not setting.valid?
    assert_includes setting.errors[:map_center_latitude], 'must be less than or equal to 90'
    assert_includes setting.errors[:map_center_longitude], 'must be greater than or equal to -180'
    assert_includes setting.errors[:map_radius_miles], 'must be greater than 0'
  end

  test 'map defaults require fallback city and state' do
    setting = default_settings(:one)
    setting.map_default_city = ''
    setting.map_default_state = ''

    assert_not setting.valid?
    assert_includes setting.errors[:map_default_city], "can't be blank"
    assert_includes setting.errors[:map_default_state], "can't be blank"
  end
end
