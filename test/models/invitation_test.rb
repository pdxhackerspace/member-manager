require 'test_helper'

class InvitationTest < ActiveSupport::TestCase
  # email_not_already_registered validation

  test 'valid when email is not already registered' do
    invitation = Invitation.new(
      email: 'brandnew@example.com',
      membership_type: 'member',
      invited_by: users(:one)
    )
    assert_predicate invitation, :valid?
  end

  test 'invalid when email belongs to an existing user' do
    invitation = Invitation.new(
      email: users(:one).email,
      membership_type: 'member',
      invited_by: users(:two)
    )
    assert_not invitation.valid?
    assert_match(/already registered/, invitation.errors[:email].first)
  end

  test 'email already registered error includes the username' do
    invitation = Invitation.new(
      email: users(:one).email,
      membership_type: 'member',
      invited_by: users(:two)
    )
    invitation.valid?
    assert_match(/@#{users(:one).username}/, invitation.errors[:email].first)
  end

  test 'email check is case-insensitive' do
    invitation = Invitation.new(
      email: users(:one).email.upcase,
      membership_type: 'member',
      invited_by: users(:two)
    )
    assert_not invitation.valid?
    assert_match(/already registered/, invitation.errors[:email].first)
  end

  test 'email validation only runs on create, not update' do
    # The accepted invitation's email is not a registered user email,
    # but even if it were, updating an existing invitation should not re-validate this
    existing = invitations(:accepted)
    existing.membership_type = 'guest'
    assert_predicate existing, :valid?
  end

  # State predicates

  test 'pending? is true for a fresh invitation' do
    assert_predicate invitations(:pending), :pending?
  end

  test 'accepted? is true after acceptance' do
    assert_predicate invitations(:accepted), :accepted?
  end

  test 'expired? is true past expires_at' do
    assert_predicate invitations(:expired), :expired?
  end

  test 'cancelled? is true after cancellation' do
    assert_predicate invitations(:cancelled), :cancelled?
  end

  test 'cancel! sets cancelled_at' do
    inv = invitations(:pending)
    assert_nil inv.cancelled_at
    inv.cancel!
    assert_not_nil inv.reload.cancelled_at
  end
end
