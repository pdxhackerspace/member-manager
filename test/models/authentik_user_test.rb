require 'test_helper'

class AuthentikUserTest < ActiveSupport::TestCase
  # Records are built through the model rather than loaded from fixtures so the email
  # columns actually hold ciphertext. Fixtures are inserted as plaintext, which would hide
  # exactly the bug these tests cover.
  def build_pair(authentik_email:, user_email:, full_name: 'Ada Lovelace', username: nil)
    username ||= "ada-#{SecureRandom.hex(4)}"
    user = User.create!(
      authentik_id: "user-#{SecureRandom.hex(4)}",
      email: user_email, full_name: full_name, username: username
    )
    authentik_user = AuthentikUser.create!(
      authentik_id: "ak-#{SecureRandom.hex(4)}",
      email: authentik_email, full_name: full_name, username: username, user: user
    )
    [authentik_user, user]
  end

  test 'matching records are not reported as discrepancies' do
    authentik_user, = build_pair(authentik_email: 'ada@example.com', user_email: 'ada@example.com')

    assert_empty authentik_user.discrepancies
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'the same address encrypted twice still counts as matching' do
    authentik_user, user = build_pair(authentik_email: 'ada@example.com', user_email: 'ada@example.com')

    # Each column is encrypted under its own nonce, so the stored values differ even though
    # the addresses are identical. Comparing the columns directly would flag every account.
    assert_not_equal authentik_user[:email], user[:email]
    assert_equal authentik_user.email, user.email
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'a differing email is reported as a discrepancy' do
    authentik_user, = build_pair(authentik_email: 'ada@example.com', user_email: 'grace@example.com')

    assert_includes AuthentikUser.with_discrepancies, authentik_user
    assert_equal ['email'], authentik_user.discrepancies.pluck(:field)
  end

  test 'email casing and surrounding space do not count as a discrepancy' do
    authentik_user, = build_pair(authentik_email: '  Ada@Example.COM ', user_email: 'ada@example.com')

    assert_empty authentik_user.discrepancies
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'a differing name is still reported' do
    authentik_user, = build_pair(authentik_email: 'ada@example.com', user_email: 'ada@example.com')
    authentik_user.update!(full_name: 'Ada King')

    assert_includes AuthentikUser.with_discrepancies, authentik_user
    assert_equal ['full_name'], authentik_user.discrepancies.pluck(:field)
  end

  test 'the scope agrees with the per-record check' do
    build_pair(authentik_email: 'match@example.com', user_email: 'match@example.com')
    build_pair(authentik_email: 'left@example.com', user_email: 'right@example.com')

    scoped = AuthentikUser.with_discrepancies.pluck(:id).sort
    per_record = AuthentikUser.linked.select(&:has_discrepancies?).map(&:id).sort

    assert_equal per_record, scoped
  end

  test 'an unlinked authentik user is never reported' do
    authentik_user = AuthentikUser.create!(authentik_id: 'ak-unlinked', email: 'nobody@example.com')

    assert_empty authentik_user.discrepancies
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end
end
