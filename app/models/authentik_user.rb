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
  # `String#strip` removes tabs and newlines as well as spaces, so SQL trims the same set.
  # It deliberately does not fold case: Postgres LOWER and Ruby downcase disagree on some
  # Unicode — LOWER('İ') is 'i' where 'İ'.downcase is 'i̇' — and a SQL test that merged
  # more than Ruby does would drop a pair #discrepancies calls different. Comparing
  # case-sensitively can only add candidates, and Ruby throws those back out.
  STRIPPED_WHITESPACE = "E' \\t\\n\\v\\f\\r'".freeze

  class << self
    # SQL cannot decrypt, so it can only prove an address pair equal two ways: matching
    # lookup digests, or matching raw columns for rows written before the backfill that
    # still hold plaintext. The digest is HMAC over the same strip-and-downcase
    # #normalize_value applies, so digests agreeing really does mean the addresses do.
    def email_proven_equal
      '(authentik_users.email_lookup_digest IS NOT NULL ' \
        'AND authentik_users.email_lookup_digest IS NOT DISTINCT FROM users.email_lookup_digest) ' \
        "OR #{trimmed('authentik_users.email')} = #{trimmed('users.email')}"
    end

    def name_or_username_differs
      "#{trimmed('authentik_users.full_name')} != #{trimmed('users.full_name')} " \
        "OR #{trimmed('authentik_users.username')} != #{trimmed('users.username')}"
    end

    def trimmed(column)
      "BTRIM(COALESCE(#{column}, ''), #{STRIPPED_WHITESPACE})"
    end
  end

  # Every pair that might differ. It over-reports — a digest on one side and ciphertext
  # on the other describe the same address without matching either way, and casing alone
  # lands here too — but it never drops a pair that genuinely differs.
  scope :discrepancy_candidates, lambda {
    joins(:user).includes(:user).where("NOT (#{email_proven_equal}) OR #{name_or_username_differs}")
  }

  # #discrepancies is the only thing that decides, so the filter, the count and the row
  # detail cannot disagree. SQL's job is purely to keep this from decrypting an address
  # for every linked account; it is never allowed to confirm a pair on its own, because
  # its idea of equality is not Ruby's.
  scope :with_discrepancies, -> { where(id: discrepancy_ids) }

  def self.discrepancy_ids
    discrepancy_candidates.select(&:has_discrepancies?).map(&:id)
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
