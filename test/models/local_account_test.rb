require 'test_helper'

class LocalAccountTest < ActiveSupport::TestCase
  test 'requires a unique email' do
    existing = local_accounts(:active_admin)
    duplicate = LocalAccount.new(email: existing.email, password: 'anotherpassword123')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], 'has already been taken'
  end

  # Sign-in accounts, so the duplicate the validation cannot see must not reach the table:
  # encryption left the email column unable to catch it, which leaves the digest index.
  test 'the database refuses a second account holding the same address' do
    LocalAccount.create!(email: 'contested@example.com', password: 'firstpassword123')
    duplicate = LocalAccount.new(email: 'contested@example.com', password: 'anotherpassword123')
    duplicate.validate # fills in the digest the way a racing create would

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate.save!(validate: false)
    end
  end

  test 'enforces minimum password length' do
    account = LocalAccount.new(email: 'new@example.com', password: 'short')

    assert_not account.valid?
    assert_includes account.errors[:password], 'is too short (minimum is 12 characters)'
  end
end
