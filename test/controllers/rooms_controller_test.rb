require 'test_helper'

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV['LOCAL_AUTH_ENABLED'] = 'true'
    sign_in_as_admin
    @room = rooms(:woodshop)
  end

  teardown do
    ENV.delete('LOCAL_AUTH_ENABLED')
  end

  test 'index lists rooms' do
    get rooms_url
    assert_response :success
    assert_select 'td', text: 'Woodshop'
  end

  test 'new renders form' do
    get new_room_url
    assert_response :success
    assert_select 'input[name="room[name]"]'
  end

  test 'create saves a valid room' do
    assert_difference 'Room.count', 1 do
      post rooms_url, params: { room: { name: 'New Room', position: 5 } }
    end
    assert_redirected_to rooms_path
  end

  test 'create rejects invalid room' do
    assert_no_difference 'Room.count' do
      post rooms_url, params: { room: { name: '' } }
    end
    assert_response :unprocessable_content
  end

  test 'edit renders form' do
    get edit_room_url(@room)
    assert_response :success
  end

  test 'update modifies room' do
    patch room_url(@room), params: { room: { name: 'Updated Room' } }
    assert_redirected_to rooms_path
    assert_equal 'Updated Room', @room.reload.name
  end

  test 'destroy removes room' do
    assert_difference 'Room.count', -1 do
      delete room_url(@room)
    end
    assert_redirected_to rooms_path
  end

  private

  def sign_in_as_admin
    Rails.application.config.x.local_auth.enabled = true
    post local_login_path, params: {
      session: { email: 'admin@example.com', password: 'localpassword123' }
    }
    User.find_by('authentik_id LIKE ?', 'local:%')&.tap { |u| u.update!(is_admin: true) }
  end
end
