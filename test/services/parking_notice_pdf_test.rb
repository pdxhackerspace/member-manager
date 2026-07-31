require 'test_helper'

class ParkingNoticePdfTest < ActiveSupport::TestCase
  setup do
    @notice = parking_notices(:active_permit)
  end

  test 'renders non-empty PDF' do
    pdf = ParkingNoticePdf.new(@notice)
    assert pdf.document.render.bytesize.positive?
  end

  test 'renders PDF when member has slack handle' do
    @notice.user.update!(slack_handle: 'permitslack')

    pdf = ParkingNoticePdf.new(@notice)
    assert pdf.document.render.bytesize.positive?
    assert_equal "#{@notice.user.username} @permitslack", @notice.user.parking_member_label
  end
end
