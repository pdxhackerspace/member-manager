require 'test_helper'

class MessageTest < ActiveSupport::TestCase
  setup do
    @sender = users(:one)
    @recipient = users(:two)
  end

  test 'valid message saves successfully' do
    message = Message.new(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test body')
    assert message.valid?
    assert message.save
  end

  test 'requires subject' do
    message = Message.new(sender: @sender, recipient: @recipient, subject: '', body: 'Test body')
    assert_not message.valid?
    assert_includes message.errors[:subject], "can't be blank"
  end

  test 'requires body' do
    message = Message.new(sender: @sender, recipient: @recipient, subject: 'Hello', body: '')
    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test 'requires sender' do
    message = Message.new(recipient: @recipient, subject: 'Hello', body: 'Test body')
    assert_not message.valid?
    assert message.errors[:sender].any?
  end

  test 'requires recipient' do
    message = Message.new(sender: @sender, subject: 'Hello', body: 'Test body')
    assert_not message.valid?
    assert message.errors[:recipient].any?
  end

  test 'unread? returns true when read_at is nil' do
    message = Message.create!(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test')
    assert message.unread?
  end

  test 'unread? returns false after read!' do
    message = Message.create!(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test')
    message.read!
    assert_not message.unread?
    assert_not_nil message.read_at
  end

  test 'read! is idempotent' do
    message = Message.create!(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test')
    message.read!
    first_read_at = message.read_at
    message.read!
    assert_equal first_read_at, message.read_at
  end

  test 'newest_first scope orders by created_at desc' do
    Message.create!(sender: @sender, recipient: @recipient, subject: 'Old', body: 'Old message')
    new_msg = Message.create!(sender: @sender, recipient: @recipient, subject: 'New', body: 'New message')

    results = Message.newest_first
    assert_equal new_msg, results.first
  end

  test 'unread scope returns only unread messages' do
    unread = Message.create!(sender: @sender, recipient: @recipient, subject: 'Unread', body: 'Test')
    read_msg = Message.create!(sender: @sender, recipient: @recipient, subject: 'Read', body: 'Test')
    read_msg.read!

    results = Message.unread
    assert_includes results, unread
    assert_not_includes results, read_msg
  end

  test 'for_user scope returns messages for the given recipient' do
    msg_for_two = Message.create!(sender: @sender, recipient: @recipient, subject: 'For two', body: 'Test')
    msg_for_one = Message.create!(sender: @recipient, recipient: @sender, subject: 'For one', body: 'Test')

    results = Message.for_user(@recipient)
    assert_includes results, msg_for_two
    assert_not_includes results, msg_for_one
  end

  test 'user sent_messages association' do
    message = Message.create!(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test')
    assert_includes @sender.sent_messages, message
  end

  test 'user received_messages association' do
    message = Message.create!(sender: @sender, recipient: @recipient, subject: 'Hello', body: 'Test')
    assert_includes @recipient.received_messages, message
  end
end
