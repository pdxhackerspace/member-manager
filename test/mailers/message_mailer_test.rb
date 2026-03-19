require 'test_helper'

class MessageMailerTest < ActionMailer::TestCase
  setup do
    @sender = users(:one)
    @recipient = users(:two)
    @message = Message.create!(
      sender: @sender,
      recipient: @recipient,
      subject: 'Test Subject',
      body: 'This is the message body.'
    )
  end

  test 'message_received sends to recipient' do
    email = MemberMailer.message_received(@message)

    assert_equal [@recipient.email], email.to
    assert_includes email.subject, 'Test Subject'
    assert_includes email.subject, @sender.display_name
  end

  test 'message_received includes message body in html' do
    email = MemberMailer.message_received(@message)
    html_body = email.html_part&.body&.to_s || email.body.to_s

    assert_includes html_body, 'This is the message body.'
    assert_includes html_body, @sender.display_name
  end

  test 'message_received includes message body in text' do
    email = MemberMailer.message_received(@message)
    text_body = email.text_part&.body&.to_s

    if text_body.present?
      assert_includes text_body, 'This is the message body.'
      assert_includes text_body, @sender.display_name
    end
  end
end
