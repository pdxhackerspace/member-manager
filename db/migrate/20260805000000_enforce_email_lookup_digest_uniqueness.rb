# Encryption moved the one-row-per-address guarantee off the email columns: every row carries
# its own nonce, so two rows holding the same address store different ciphertext and a unique
# index over it accepts them both. SlackUser and LocalAccount both validate their lookup digest
# for uniqueness, but only users had the matching index, leaving those two to a race where
# concurrent creates each pass validation and then both persist.
class EnforceEmailLookupDigestUniqueness < ActiveRecord::Migration[8.1]
  def change
    # Where the guarantee actually lives now.
    remove_index :slack_users, :email_lookup_digest, name: 'index_slack_users_on_email_lookup_digest'
    add_index :slack_users, :email_lookup_digest,
              unique: true, where: 'email_lookup_digest IS NOT NULL',
              name: 'index_slack_users_on_email_lookup_digest'

    remove_index :local_accounts, :email_lookup_digest, name: 'index_local_accounts_on_email_lookup_digest'
    add_index :local_accounts, :email_lookup_digest,
              unique: true, where: 'email_lookup_digest IS NOT NULL',
              name: 'index_local_accounts_on_email_lookup_digest'

    # And off the ciphertext, which cannot enforce it and reads as though it still does.
    remove_index :slack_users, :email, unique: true, where: '(email IS NOT NULL)',
                                       name: 'index_slack_users_on_email'
    remove_index :local_accounts, :email, unique: true, name: 'index_local_accounts_on_email'
  end
end
