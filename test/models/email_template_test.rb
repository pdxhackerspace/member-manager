require 'test_helper'

class EmailTemplateTest < ActiveSupport::TestCase
  test 'block send immediately forces send immediately off' do
    template = EmailTemplate.new(
      key: 'blocked_immediate_test',
      name: 'Blocked Immediate Test',
      subject: 'Hello',
      body_html: '<p>Hello</p>',
      body_text: 'Hello',
      send_immediately: true,
      block_send_immediately: true
    )

    assert template.valid?
    assert_not template.send_immediately?
  end
end
