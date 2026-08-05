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

  # Mimics a row written before the backfill, or by raw SQL: a plaintext address with no
  # digest alongside it.
  def store_as_plaintext(record, address)
    record.update_columns(email: address, email_lookup_digest: nil)
    record.reload
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

  # Rows written before the backfill, or by raw SQL, carry a plaintext address and no
  # digest. Comparing digests alone reads those wrong in both directions, so the scope
  # confirms its candidates against #discrepancies.
  test 'two plaintext addresses that differ are still reported' do
    authentik_user, user = build_pair(authentik_email: 'left@example.com', user_email: 'right@example.com')
    store_as_plaintext(authentik_user, 'left@example.com')
    store_as_plaintext(user, 'right@example.com')

    assert authentik_user.has_discrepancies?
    assert_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'a plaintext address matching an encrypted one is not reported' do
    authentik_user, user = build_pair(authentik_email: 'same@example.com', user_email: 'same@example.com')
    store_as_plaintext(user, 'same@example.com')

    assert_empty authentik_user.discrepancies
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'the scope matches the per-record check however the address is stored' do
    [
      ['both encrypted, same address',      :encrypted, :encrypted, true],
      ['both encrypted, differing',         :encrypted, :encrypted, false],
      ['both plaintext, same address',      :plaintext, :plaintext, true],
      ['both plaintext, differing',         :plaintext, :plaintext, false],
      ['digest against plaintext, same',    :encrypted, :plaintext, true],
      ['digest against plaintext, differing', :encrypted, :plaintext, false]
    ].each_with_index do |(label, authentik_storage, user_storage, same_address), index|
      authentik_email = "case#{index}@example.com"
      user_email = same_address ? authentik_email : "case#{index}-other@example.com"

      authentik_user, user = build_pair(authentik_email: authentik_email, user_email: user_email)
      store_as_plaintext(authentik_user, authentik_email) if authentik_storage == :plaintext
      store_as_plaintext(user, user_email) if user_storage == :plaintext
      authentik_user.reload

      assert_equal !same_address, authentik_user.has_discrepancies?, label
      assert_equal authentik_user.has_discrepancies?,
                   AuthentikUser.with_discrepancies.exists?(id: authentik_user.id),
                   "scope disagreed with #discrepancies for: #{label}"
    end
  end

  test 'the candidate query never drops a pair that genuinely differs' do
    authentik_user, user = build_pair(authentik_email: 'left@example.com', user_email: 'right@example.com')
    store_as_plaintext(user, 'right@example.com')

    assert authentik_user.has_discrepancies?
    assert_includes AuthentikUser.discrepancy_candidates, authentik_user
  end

  # with_discrepancies rests on the two scopes covering every candidate between them.
  # A pair falling through both gaps would silently vanish from the report.
  test 'the settled and undecided scopes together cover every candidate' do
    build_pair(authentik_email: 'same@example.com', user_email: 'same@example.com')
    build_pair(authentik_email: 'a@example.com', user_email: 'b@example.com')
    named, = build_pair(authentik_email: 'n@example.com', user_email: 'n@example.com')
    named.update!(full_name: 'Someone Else')
    partial, user = build_pair(authentik_email: 'p@example.com', user_email: 'q@example.com')
    user.update_columns(email_lookup_digest: nil)
    store_as_plaintext(partial, 'p@example.com')

    candidates = AuthentikUser.discrepancy_candidates.pluck(:id).sort
    covered = (AuthentikUser.confirmed_discrepancies.pluck(:id) +
               AuthentikUser.undecided_discrepancies.pluck(:id)).sort

    assert_equal candidates, covered
    assert_empty AuthentikUser.confirmed_discrepancies.pluck(:id) &
                 AuthentikUser.undecided_discrepancies.pluck(:id),
                 'a pair was both settled and left undecided'
  end

  # The point of splitting the scope: a pair SQL can settle never reaches Ruby, so the
  # index does not decrypt an address for every linked account.
  test 'pairs SQL can settle are not left for the per-record check' do
    matching, = build_pair(authentik_email: 'settled@example.com', user_email: 'settled@example.com')
    differing, = build_pair(authentik_email: 'left@example.com', user_email: 'right@example.com')

    assert_not_includes AuthentikUser.undecided_discrepancies, matching
    assert_not_includes AuthentikUser.undecided_discrepancies, differing
    assert_includes AuthentikUser.confirmed_discrepancies, differing
  end

  test 'a pair with a digest on one side and ciphertext on the other is decided in ruby' do
    authentik_user, user = build_pair(authentik_email: 'left@example.com', user_email: 'right@example.com')
    user.update_columns(email_lookup_digest: nil)

    assert_includes AuthentikUser.undecided_discrepancies, authentik_user.reload
    assert_includes AuthentikUser.with_discrepancies, authentik_user
  end

  test 'names differing only by a tab agree between the scope and the per-record check' do
    authentik_user, = build_pair(authentik_email: 'tab@example.com', user_email: 'tab@example.com')
    authentik_user.update!(full_name: "Ada Lovelace\t")

    assert_equal authentik_user.has_discrepancies?,
                 AuthentikUser.with_discrepancies.exists?(id: authentik_user.id)
  end

  test 'an unlinked authentik user is never reported' do
    authentik_user = AuthentikUser.create!(authentik_id: 'ak-unlinked', email: 'nobody@example.com')

    assert_empty authentik_user.discrepancies
    assert_not_includes AuthentikUser.with_discrepancies, authentik_user
  end
end
