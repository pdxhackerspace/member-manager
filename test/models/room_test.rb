require 'test_helper'

class RoomTest < ActiveSupport::TestCase
  test 'valid room saves' do
    room = Room.new(name: 'Test Room', position: 0)
    assert room.valid?
  end

  test 'name is required' do
    room = Room.new(name: nil)
    assert_not room.valid?
    assert_includes room.errors[:name], "can't be blank"
  end

  test 'name must be unique' do
    Room.create!(name: 'Unique Room')
    duplicate = Room.new(name: 'Unique Room')
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], 'has already been taken'
  end

  test 'ordered scope sorts by position then name' do
    rooms = Room.ordered.pluck(:name)
    assert_equal(rooms, rooms.sort_by { |n| [Room.find_by(name: n).position, n] })
  end

  test 'to_s returns name' do
    room = rooms(:woodshop)
    assert_equal 'Woodshop', room.to_s
  end
end
