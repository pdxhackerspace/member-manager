# SPDX-FileCopyrightText: 2026 John Romkey
#
# SPDX-License-Identifier: CC0-1.0

class AuthentikUser < ApplicationRecord
  include SensitiveFields

  encrypts_sensitive_string :email
  encrypts_sensitive_json :raw_attributes
  has_email_lookup :email, digest_column: :email_lookup_digest

  belongs_to :user, optional: true

  validates :authentik_id, presence: true, uniqueness: true

  scope :linked, -> { where.not(user_id: nil) }
  scope :unlinked, -> { where(user_id: nil) }
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  # `String#strip` removes tabs and newlines as well as spaces, so SQL has to trim the
  # same set for a pair it calls different to be one #discrepancies also calls different.
  STRIPPED_WHITESPACE = "E' \\t\\n\\v\\f\\r'".freeze

  class << self
    # SQL cannot decrypt, so it can only settle an address pair three ways: matching
    # lookup digests prove equality, two digests that both exist and disagree prove
    # difference, and matching raw columns prove equality for rows written before the
    # backfill that still hold plaintext. Anything else — a digest on one side and
    # ciphertext on the other — it cannot judge at all.
    def email_proven_equal
      '(authentik_users.email_lookup_digest IS NOT NULL ' \
        'AND authentik_users.email_lookup_digest IS NOT DISTINCT FROM users.email_lookup_digest) ' \
        "OR #{normalized('authentik_users.email')} = #{normalized('users.email')}"
    end

    def email_proven_different
      'authentik_users.email_lookup_digest IS NOT NULL AND users.email_lookup_digest IS NOT NULL ' \
        'AND authentik_users.email_lookup_digest IS DISTINCT FROM users.email_lookup_digest'
    end

    def name_or_username_differs
      "#{normalized('authentik_users.full_name')} != #{normalized('users.full_name')} " \
        "OR #{normalized('authentik_users.username')} != #{normalized('users.username')}"
    end

    def normalized(column)
      "LOWER(BTRIM(COALESCE(#{column}, ''), #{STRIPPED_WHITESPACE}))"
    end
  end

  # Every pair that might differ. Kept because it is the guarantee the other scopes rest
  # on: it can over-report, but it never drops a pair that genuinely differs.
  scope :discrepancy_candidates, lambda {
    joins(:user).includes(:user).where("NOT (#{email_proven_equal}) OR #{name_or_username_differs}")
  }

  # Pairs SQL settles on its own — a name or username that differs, or two digests that
  # disagree. No decryption needed, and the normalization above matches #normalize_value
  # so these agree with #discrepancies.
  scope :confirmed_discrepancies, lambda {
    joins(:user).where("#{name_or_username_differs} OR (#{email_proven_different})")
  }

  # The remainder: pairs whose addresses SQL can neither match nor separate. These are
  # the only ones that have to be decrypted, and there are none left once every row
  # carries a lookup digest.
  scope :undecided_discrepancies, lambda {
    joins(:user).includes(:user).where(
      "NOT (#{name_or_username_differs}) AND NOT (#{email_proven_equal}) AND NOT (#{email_proven_different})"
    )
  }

  # The filter, the count and the row detail cannot disagree whatever state the digest
  # columns are in, because #discrepancies settles every pair SQL could not.
  scope :with_discrepancies, -> { where(id: discrepancy_ids) }

  def self.discrepancy_ids
    confirmed_discrepancies.pluck(:id) +
      undecided_discrepancies.select(&:has_discrepancies?).map(&:id)
  end

  # Returns an array of field discrepancies between this AuthentikUser and its linked User
  def discrepancies
    return [] unless user

    diffs = []

    if normalize_value(email) != normalize_value(user.email)
      diffs << { field: 'email', authentik: email, user: user.email }
    end

    if normalize_value(full_name) != normalize_value(user.full_name)
      diffs << { field: 'full_name', authentik: full_name, user: user.full_name }
    end

    if normalize_value(username) != normalize_value(user.username)
      diffs << { field: 'username', authentik: username, user: user.username }
    end

    diffs
  end

  def has_discrepancies?
    discrepancies.any?
  end

  def display_name
    full_name.presence || username.presence || email.presence || authentik_id
  end

  private

  def normalize_value(value)
    value.to_s.strip.downcase
  end
end
