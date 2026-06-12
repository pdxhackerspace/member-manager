require 'test_helper'

class ParkingNoticesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV['LOCAL_AUTH_ENABLED'] = 'true'
    sign_in_as_admin
    @active_permit = parking_notices(:active_permit)
    @expired_ticket = parking_notices(:expired_ticket)
  end

  teardown do
    ENV.delete('LOCAL_AUTH_ENABLED')
  end

  # --- Index ---

  test 'index shows parking notices' do
    get parking_notices_url
    assert_response :success
    assert_select 'table'
  end

  test 'index filters by status' do
    get parking_notices_url(status: 'active')
    assert_response :success
  end

  test 'index filters by type' do
    get parking_notices_url(type: 'permit')
    assert_response :success
  end

  # --- Show ---

  test 'show displays parking notice' do
    get parking_notice_url(@active_permit)
    assert_response :success
    assert_select '.badge', text: 'Permit'
  end

  # --- New ---

  test 'new renders permit form' do
    get new_parking_notice_url(type: 'permit')
    assert_response :success
    assert_select 'input[name="parking_notice[notice_type]"][value="permit"]'
    assert_select 'input[name="create_another_permit"][value="Save and Create Another Permit"]'
    assert_select 'input[name="print_create_another_permit"][value="Save, Print and Create Another Permit"]'
    assert_expiration_quick_buttons
  end

  test 'new pre-fills permit form from params' do
    user = users(:one)

    get new_parking_notice_url(
      type: 'permit',
      parking_notice: {
        user_id: user.id,
        description: 'Repeat permit',
        expires_at: '2026-06-01T17:00',
        location: 'Woodshop',
        location_detail: 'South wall shelf'
      }
    )

    assert_response :success
    assert_select 'input[name="parking_notice[user_id]"][value=?]', user.id.to_s
    assert_select 'input#pn_member_search[value=?]', user.display_name
    assert_select 'textarea[name="parking_notice[description]"]', text: 'Repeat permit'
    assert_select 'input[name="parking_notice[expires_at]"][value="2026-06-01T17:00"]'
    assert_select 'input[name="parking_notice[location]"][value="Woodshop"]'
    assert_select 'input[name="parking_notice[location_detail]"][value="South wall shelf"]'
  end

  test 'member search includes email and username fields' do
    user = users(:one)

    get new_parking_notice_url(type: 'permit')
    assert_response :success

    assert_select '.pn-member-item[data-user-id=?][data-user-email=?][data-username=?]',
                  user.id.to_s, user.email, user.username
  end

  test 'new renders ticket form' do
    get new_parking_notice_url(type: 'ticket')
    assert_response :success
    assert_select 'input[name="parking_notice[notice_type]"][value="ticket"]'
    assert_select 'input[name="create_another_permit"]', false
    assert_select 'input[name="print_create_another_permit"]', false
    assert_expiration_quick_buttons
  end

  # --- Create ---

  test 'create saves a valid permit' do
    user = users(:one)
    assert_difference 'ParkingNotice.count', 1 do
      post parking_notices_url, params: {
        parking_notice: {
          notice_type: 'permit',
          user_id: user.id,
          description: 'Test permit',
          location: 'Woodshop',
          expires_at: 7.days.from_now
        }
      }
    end
    assert_redirected_to parking_notice_path(ParkingNotice.last)
  end

  test 'create can save and start another permit with matching fields' do
    user = users(:one)
    expires_at = '2026-06-01T17:00'

    assert_difference 'ParkingNotice.count', 1 do
      post parking_notices_url, params: {
        create_another_permit: 'Save and Create Another Permit',
        parking_notice: {
          notice_type: 'permit',
          user_id: user.id,
          description: 'Repeat permit',
          expires_at: expires_at,
          location: 'Woodshop',
          location_detail: 'South wall shelf'
        }
      }
    end

    location = URI.parse(response.location)
    redirect_params = Rack::Utils.parse_nested_query(location.query)

    assert_equal new_parking_notice_path, location.path
    assert_equal 'permit', redirect_params['type']
    assert_equal user.id.to_s, redirect_params.dig('parking_notice', 'user_id')
    assert_equal 'Repeat permit', redirect_params.dig('parking_notice', 'description')
    assert_equal expires_at, redirect_params.dig('parking_notice', 'expires_at')
    assert_equal 'Woodshop', redirect_params.dig('parking_notice', 'location')
    assert_equal 'South wall shelf', redirect_params.dig('parking_notice', 'location_detail')
  end

  test 'create can save print and start another permit with matching fields' do
    user = users(:one)
    printer = Printer.create!(name: 'Default Printer', cups_printer_name: 'default_printer', default_printer: true)
    expires_at = '2026-06-01T17:00'
    printed = nil
    original_print_data = CupsService.method(:print_data)

    CupsService.define_singleton_method(:print_data) do |data, cups_printer_name,
                                                        cups_printer_server:, filename:, options:|
      printed = {
        data: data,
        cups_printer_name: cups_printer_name,
        cups_printer_server: cups_printer_server,
        filename: filename,
        options: options
      }
      'default-printer-42'
    end

    begin
      assert_difference 'ParkingNotice.count', 1 do
        post parking_notices_url, params: {
          print_create_another_permit: 'Save, Print and Create Another Permit',
          parking_notice: {
            notice_type: 'permit',
            user_id: user.id,
            description: 'Repeat printed permit',
            expires_at: expires_at,
            location: 'Woodshop',
            location_detail: 'South wall shelf'
          }
        }
      end
    ensure
      CupsService.define_singleton_method(:print_data, original_print_data)
    end

    notice = ParkingNotice.order(:created_at).last
    location = URI.parse(response.location)
    redirect_params = Rack::Utils.parse_nested_query(location.query)

    assert_equal new_parking_notice_path, location.path
    assert_equal 'permit', redirect_params['type']
    assert_equal user.id.to_s, redirect_params.dig('parking_notice', 'user_id')
    assert_equal 'Repeat printed permit', redirect_params.dig('parking_notice', 'description')
    assert_equal expires_at, redirect_params.dig('parking_notice', 'expires_at')
    assert_equal 'Woodshop', redirect_params.dig('parking_notice', 'location')
    assert_equal 'South wall shelf', redirect_params.dig('parking_notice', 'location_detail')
    assert_equal "Parking permit created and printed to #{printer.name} (job default-printer-42).", flash[:notice]
    assert_equal 'default_printer', printed[:cups_printer_name]
    assert_equal '', printed[:cups_printer_server]
    assert_equal "parking_notice_#{notice.id}.pdf", printed[:filename]
    assert_equal({}, printed[:options])
    assert_predicate printed[:data], :present?
  end

  test 'create print another still saves when no default printer is configured' do
    user = users(:one)
    expires_at = '2026-06-01T17:00'

    assert_no_difference 'Printer.count' do
      assert_difference 'ParkingNotice.count', 1 do
        post parking_notices_url, params: {
          print_create_another_permit: 'Save, Print and Create Another Permit',
          parking_notice: {
            notice_type: 'permit',
            user_id: user.id,
            description: 'Repeat unprinted permit',
            expires_at: expires_at,
            location: 'Woodshop',
            location_detail: 'South wall shelf'
          }
        }
      end
    end

    location = URI.parse(response.location)
    redirect_params = Rack::Utils.parse_nested_query(location.query)

    assert_equal new_parking_notice_path, location.path
    assert_equal 'permit', redirect_params['type']
    assert_equal user.id.to_s, redirect_params.dig('parking_notice', 'user_id')
    assert_equal 'Repeat unprinted permit', redirect_params.dig('parking_notice', 'description')
    assert_equal expires_at, redirect_params.dig('parking_notice', 'expires_at')
    assert_equal 'Woodshop', redirect_params.dig('parking_notice', 'location')
    assert_equal 'South wall shelf', redirect_params.dig('parking_notice', 'location_detail')
    assert_equal 'Parking permit created successfully.', flash[:notice]
    assert_equal 'No default printer is configured.', flash[:alert]
  end

  test 'create print another still saves when printing fails' do
    user = users(:one)
    Printer.create!(name: 'Default Printer', cups_printer_name: 'default_printer', default_printer: true)
    expires_at = '2026-06-01T17:00'
    original_print_data = CupsService.method(:print_data)

    CupsService.define_singleton_method(:print_data) do |*_args, **_kwargs|
      raise CupsService::PrintError, 'printer is offline'
    end

    begin
      assert_difference 'ParkingNotice.count', 1 do
        post parking_notices_url, params: {
          print_create_another_permit: 'Save, Print and Create Another Permit',
          parking_notice: {
            notice_type: 'permit',
            user_id: user.id,
            description: 'Repeat failed print permit',
            expires_at: expires_at,
            location: 'Woodshop',
            location_detail: 'South wall shelf'
          }
        }
      end
    ensure
      CupsService.define_singleton_method(:print_data, original_print_data)
    end

    location = URI.parse(response.location)
    redirect_params = Rack::Utils.parse_nested_query(location.query)

    assert_equal new_parking_notice_path, location.path
    assert_equal 'permit', redirect_params['type']
    assert_equal user.id.to_s, redirect_params.dig('parking_notice', 'user_id')
    assert_equal 'Repeat failed print permit', redirect_params.dig('parking_notice', 'description')
    assert_equal expires_at, redirect_params.dig('parking_notice', 'expires_at')
    assert_equal 'Woodshop', redirect_params.dig('parking_notice', 'location')
    assert_equal 'South wall shelf', redirect_params.dig('parking_notice', 'location_detail')
    assert_equal 'Parking permit created successfully.', flash[:notice]
    assert_equal 'Print failed: printer is offline', flash[:alert]
  end

  test 'create saves a ticket without user' do
    assert_difference 'ParkingNotice.count', 1 do
      post parking_notices_url, params: {
        parking_notice: {
          notice_type: 'ticket',
          description: 'Anonymous ticket',
          location: 'Main Area',
          expires_at: 3.days.from_now
        }
      }
    end
    assert_redirected_to parking_notice_path(ParkingNotice.last)
  end

  test 'create rejects invalid permit (missing user)' do
    assert_no_difference 'ParkingNotice.count' do
      post parking_notices_url, params: {
        parking_notice: {
          notice_type: 'permit',
          description: 'No user',
          expires_at: 7.days.from_now
        }
      }
    end
    assert_response :unprocessable_content
  end

  # --- Edit / Update ---

  test 'edit renders form' do
    get edit_parking_notice_url(@active_permit)
    assert_response :success
  end

  test 'update modifies notice' do
    patch parking_notice_url(@active_permit), params: {
      parking_notice: { description: 'Updated description' }
    }
    assert_redirected_to parking_notice_path(@active_permit)
    assert_equal 'Updated description', @active_permit.reload.description
  end

  # --- PDF Download ---

  test 'download_pdf returns a PDF' do
    get download_pdf_parking_notice_url(@active_permit)
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test 'create saves a ticket that requires admin clearance' do
    assert_difference 'ParkingNotice.count', 1 do
      post parking_notices_url, params: {
        parking_notice: {
          notice_type: 'ticket',
          description: 'Needs staff sign-off',
          location: 'Main Area',
          expires_at: 3.days.from_now,
          requires_admin_clearance: '1'
        }
      }
    end
    assert ParkingNotice.last.requires_admin_clearance?
  end

  # --- Clear ---

  test 'clear marks notice as cleared' do
    post clear_parking_notice_url(@active_permit)
    assert_redirected_to parking_notice_path(@active_permit)
    assert @active_permit.reload.cleared?
  end

  test 'clear logs a cleared history event' do
    assert_difference -> { @active_permit.events.count }, 1 do
      post clear_parking_notice_url(@active_permit)
    end
    assert_equal 'cleared', @active_permit.events.recent_first.first.event_type
  end

  # --- Notes / history ---

  test 'add_note records a history note' do
    assert_difference -> { @active_permit.events.count }, 1 do
      post add_note_parking_notice_url(@active_permit), params: { note: 'Called the member' }
    end
    assert_redirected_to parking_notice_path(@active_permit)
    event = @active_permit.events.recent_first.first
    assert_equal 'note', event.event_type
    assert_equal 'Called the member', event.note
  end

  test 'add_note rejects a blank note' do
    assert_no_difference -> { @active_permit.events.count } do
      post add_note_parking_notice_url(@active_permit), params: { note: '  ' }
    end
    assert_redirected_to parking_notice_path(@active_permit)
  end

  private

  def sign_in_as_admin
    Rails.application.config.x.local_auth.enabled = true
    post local_login_path, params: {
      session: { email: 'admin@example.com', password: 'localpassword123' }
    }
    User.find_by('authentik_id LIKE ?', 'local:%')&.tap { |u| u.update!(is_admin: true) }
  end

  def assert_expiration_quick_buttons
    assert_select '.quick-expire', 7
    assert_select '.quick-expire[data-days="1"]', text: '1 day'
    assert_select '.quick-expire[data-days="3"]', text: '3 days'
    assert_select '.quick-expire[data-days="7"]', text: '1 week'
    assert_select '.quick-expire[data-days="14"]', text: '2 weeks'
    assert_select '.quick-expire[data-days="30"]', text: '30 days'
    assert_select '.quick-expire[data-days="180"]', text: '180 days'
    assert_select '.quick-expire[data-years="1"]', text: '1 year'
  end
end
