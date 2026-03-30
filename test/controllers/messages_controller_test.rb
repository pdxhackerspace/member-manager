require 'test_helper'
require 'active_job/test_helper'

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @sender = users(:one)
    @recipient = users(:two)
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  # ─── Admin can send messages ───────────────────────────────────

  test 'admin can send a message' do
    sign_in_as_local_admin

    assert_difference 'Message.count', 1 do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: 'Test Subject',
        body: 'Test message body'
      }
    end

    message = Message.last
    assert_equal 'Test Subject', message.subject
    assert_equal 'Test message body', message.body
    assert_equal @recipient, message.recipient
    assert_redirected_to user_path(@recipient, tab: :messages)
    assert_equal 'Message sent.', flash[:notice]
  end

  test 'admin sending a message enqueues an email' do
    sign_in_as_local_admin

    assert_enqueued_emails 1 do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: 'Email Test',
        body: 'This should trigger an email'
      }
    end
  end

  test 'admin gets error for missing subject' do
    sign_in_as_local_admin

    assert_no_difference 'Message.count' do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: '',
        body: 'Test body'
      }
    end

    assert_redirected_to user_path(@recipient, tab: :messages)
    assert flash[:alert].present?
  end

  test 'admin gets error for missing body' do
    sign_in_as_local_admin

    assert_no_difference 'Message.count' do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: 'Test Subject',
        body: ''
      }
    end

    assert_redirected_to user_path(@recipient, tab: :messages)
    assert flash[:alert].present?
  end

  test 'admin gets error for nonexistent recipient' do
    sign_in_as_local_admin

    post messages_path, params: {
      recipient_id: 999_999,
      subject: 'Test',
      body: 'Test'
    }

    assert_redirected_to users_path
    assert_equal 'Recipient not found.', flash[:alert]
  end

  # ─── Non-admin access ─────────────────────────────────────────

  test 'non-admin cannot send messages' do
    sign_in_as_local_member

    assert_no_difference 'Message.count' do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: 'Test',
        body: 'Test'
      }
    end
  end

  test 'unauthenticated user cannot send messages' do
    assert_no_difference 'Message.count' do
      post messages_path, params: {
        recipient_id: @recipient.id,
        subject: 'Test',
        body: 'Test'
      }
    end
  end

  private

  def sign_in_as_local_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: {
        email: account.email,
        password: 'localpassword123'
      }
    }
  end

  def sign_in_as_local_member
    account = local_accounts(:regular_member)
    post local_login_path, params: {
      session: {
        email: account.email,
        password: 'memberpassword123'
      }
    }
  end
end
