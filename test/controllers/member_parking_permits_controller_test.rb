require 'test_helper'

class MemberParkingPermitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'member can open new permit form' do
    sign_in_as_member

    get new_member_parking_permit_path
    assert_response :success
    assert_match(/New Parking Permit/i, response.body)
    assert_expiration_quick_buttons
  end

  test 'member can create own parking permit' do
    sign_in_as_member
    member = User.find_by(authentik_id: "local:#{local_accounts(:regular_member).id}")

    assert_difference 'ParkingNotice.count', 1 do
      post member_parking_permits_path, params: {
        parking_notice: {
          description: 'My project',
          location: 'Woodshop',
          location_detail: 'Bench A',
          expires_at: 3.days.from_now.strftime('%Y-%m-%dT%H:%M')
        }
      }
    end

    notice = ParkingNotice.order(:created_at).last
    assert_equal 'permit', notice.notice_type
    assert_equal 'active', notice.status
    assert_equal member.id, notice.user_id
    assert_equal member.id, notice.issued_by_id
    assert_redirected_to user_path(member, tab: :parking)
  end

  test 'anonymous user cannot access member permit form' do
    get new_member_parking_permit_path
    assert_redirected_to login_path
  end

  test 'member can close own active permit' do
    sign_in_as_member
    member = User.find_by(authentik_id: "local:#{local_accounts(:regular_member).id}")
    permit = member.parking_notices.create!(
      notice_type: 'permit', status: 'active', issued_by: member,
      expires_at: 3.days.from_now, description: 'Done early', location: 'Woodshop'
    )

    patch close_member_parking_permit_path(permit)

    assert_redirected_to user_path(member, tab: :parking)
    permit.reload
    assert_equal 'cleared', permit.status
    assert_equal member.id, permit.cleared_by_id
  end

  test 'member cannot close their own ticket' do
    sign_in_as_member
    member = User.find_by(authentik_id: "local:#{local_accounts(:regular_member).id}")
    ticket = ParkingNotice.create!(
      notice_type: 'ticket', status: 'active', user: member, issued_by: member,
      expires_at: 3.days.from_now, description: 'Enforcement', location: 'Main Area'
    )

    patch close_member_parking_permit_path(ticket)

    assert_redirected_to user_path(member, tab: :parking)
    assert_equal 'active', ticket.reload.status
  end

  test "member cannot close another member's permit" do
    sign_in_as_member
    other_permit = parking_notices(:active_permit)

    patch close_member_parking_permit_path(other_permit)

    assert_equal 'active', other_permit.reload.status
  end

  test 'anonymous user cannot close a permit' do
    permit = parking_notices(:active_permit)

    patch close_member_parking_permit_path(permit)

    assert_redirected_to login_path
    assert_equal 'active', permit.reload.status
  end

  private

  def sign_in_as_member
    post local_login_path, params: {
      session: { email: local_accounts(:regular_member).email, password: 'memberpassword123' }
    }
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
