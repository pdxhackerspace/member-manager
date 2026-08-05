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
  # Narrows to the pairs that might differ. SQL cannot decrypt, so two addresses are only
  # ever proven equal here by matching lookup digests, or by matching raw columns for rows
  # written before the backfill that still hold plaintext. A pair that satisfies neither
  # test is kept, which means this can over-report — a digest on one side and plaintext on
  # the other describe the same address without matching either way — but it never drops a
  # pair that genuinely differs.
  scope :discrepancy_candidates, lambda {
    joins(:user).includes(:user).where(
      'NOT ((authentik_users.email_lookup_digest IS NOT NULL ' \
      'AND authentik_users.email_lookup_digest IS NOT DISTINCT FROM users.email_lookup_digest) ' \
      "OR LOWER(TRIM(COALESCE(authentik_users.email, ''))) = LOWER(TRIM(COALESCE(users.email, '')))) " \
      "OR LOWER(TRIM(COALESCE(authentik_users.full_name, ''))) != " \
      "LOWER(TRIM(COALESCE(users.full_name, ''))) " \
      "OR LOWER(TRIM(COALESCE(authentik_users.username, ''))) != " \
      "LOWER(TRIM(COALESCE(users.username, '')))"
    )
  }

  # Every candidate is confirmed by #discrepancies, so the filter, the count and the row
  # detail cannot disagree whatever state the digest columns are in. Narrowing in the
  # database first keeps that from costing a decrypt of every linked account.
  scope :with_discrepancies, lambda {
    where(id: discrepancy_candidates.select(&:has_discrepancies?).map(&:id))
  }

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
