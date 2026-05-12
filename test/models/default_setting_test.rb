require 'test_helper'

class DefaultSettingTest < ActiveSupport::TestCase
  test 'rfid facility prefix includes trailing comma when configured' do
    setting = default_settings(:one)
    setting.rfid_facility_code = 127

    assert_equal '127,', setting.rfid_facility_prefix
  end

  test 'rfid facility prefix is blank when facility code is not configured' do
    setting = default_settings(:one)
    setting.rfid_facility_code = nil

    assert_equal '', setting.rfid_facility_prefix
  end
end
