require 'test_helper'

class ParkingNoticeEventTest < ActiveSupport::TestCase
  setup do
    @notice = parking_notices(:active_permit)
  end

  test 'requires a valid event_type' do
    event = ParkingNoticeEvent.new(parking_notice: @notice, event_type: 'bogus')
    assert_not event.valid?
    assert_includes event.errors[:event_type], 'is not included in the list'
  end

  test 'note event requires a note' do
    event = ParkingNoticeEvent.new(parking_notice: @notice, event_type: 'note')
    assert_not event.valid?

    event.note = 'A note'
    assert event.valid?
  end

  test 'non-note events do not require a note' do
    event = ParkingNoticeEvent.new(parking_notice: @notice, event_type: 'opened')
    assert event.valid?
  end

  test 'label and icon return display strings' do
    event = ParkingNoticeEvent.new(parking_notice: @notice, event_type: 'cleared')
    assert_equal 'Cleared', event.label
    assert_equal 'bi-check-circle', event.icon
  end

  test 'chronological orders oldest first' do
    @notice.log_event!('opened')
    @notice.log_event!('renewed')

    assert_equal %w[opened renewed], @notice.events.chronological.pluck(:event_type)
  end
end
