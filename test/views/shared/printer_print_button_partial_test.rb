require 'test_helper'

class PrinterPrintButtonPartialTest < ActionView::TestCase
  setup do
    @notice = parking_notices(:active_permit)
    @printer = Printer.create!(name: 'Front Desk', cups_printer_name: 'front_desk')
  end

  test 'renders nothing when no printers are configured' do
    html = render_partial(printers: [])

    assert_predicate html.to_s.strip, :blank?
  end

  test 'renders a single print link when one printer exists' do
    html = render_partial

    assert_includes html, print_notice_parking_notice_path(@notice, printer_id: @printer.id)
    assert_includes html, 'data-turbo-method="post"'
    assert_includes html, 'btn-outline-info'
    assert_includes html, 'Print'
    assert_no_match(/dropdown-toggle/, html)
  end

  test 'renders a printer dropdown when multiple printers exist' do
    Printer.create!(name: 'Back Office', cups_printer_name: 'back_office', default_printer: true)

    html = render_partial(printers: Printer.ordered)

    assert_includes html, 'dropdown-toggle'
    assert_includes html, 'id="printer-dropdown"'
    assert_includes html, 'Front Desk'
    assert_includes html, 'Back Office'
    assert_includes html, 'Default'
  end

  test 'uses a unique dropdown id when suffix is provided' do
    Printer.create!(name: 'Back Office', cups_printer_name: 'back_office')

    html = render_partial(printers: Printer.ordered, dropdown_suffix: @notice.id)

    assert_includes html, "id=\"printer-dropdown-#{@notice.id}\""
    assert_no_match(/id="printer-dropdown"/, html)
  end

  test 'renders compact buttons when btn_size is sm' do
    html = render_partial(btn_size: :sm)

    assert_includes html, 'btn-sm'
    assert_no_match(/>\s*Print\s*</, html)
  end

  private

  def render_partial(printers: [@printer], **locals)
    render partial: 'shared/printer_print_button', locals: {
      notice: @notice,
      printers: printers,
      print_route: :print_notice_parking_notice_path,
      **locals
    }
  end
end
