class EncryptSensitiveDatabaseFields < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_email_lookup_columns
    add_column :rfid_readers, :key_lookup_digest, :string, if_not_exists: true
    add_column :rfid_readers, :key_ciphertext, :text, if_not_exists: true
    add_lookup_indexes
    backfill_encrypted_values
  end

  def down
    remove_lookup_indexes
    remove_column :rfid_readers, :key_ciphertext, if_exists: true
    remove_column :rfid_readers, :key_lookup_digest, if_exists: true
    remove_email_lookup_columns
  end

  private

  def add_email_lookup_columns
    add_column :users, :email_lookup_digest, :string, if_not_exists: true
    add_column :users, :extra_email_lookup_digests, :string, array: true, default: [], null: false,
                                                                      if_not_exists: true

    scalar_email_digest_tables.each do |table, column|
      add_column table, column, :string, if_not_exists: true
    end
  end

  def remove_email_lookup_columns
    scalar_email_digest_tables.each do |table, column|
      remove_column table, column, if_exists: true
    end

    remove_column :users, :extra_email_lookup_digests, if_exists: true
    remove_column :users, :email_lookup_digest, if_exists: true
  end

  def scalar_email_digest_tables
    {
      membership_applications: :email_lookup_digest,
      application_verifications: :email_lookup_digest,
      invitations: :email_lookup_digest,
      local_accounts: :email_lookup_digest,
      sheet_entries: :email_lookup_digest,
      slack_users: :email_lookup_digest,
      authentik_users: :email_lookup_digest,
      paypal_payments: :payer_email_lookup_digest,
      recharge_payments: :customer_email_lookup_digest,
      kofi_payments: :email_lookup_digest
    }
  end

  def add_lookup_indexes
    add_index :users, :email_lookup_digest, unique: true, where: 'email_lookup_digest IS NOT NULL',
                                           algorithm: :concurrently, if_not_exists: true
    add_index :users, :extra_email_lookup_digests, using: :gin, algorithm: :concurrently, if_not_exists: true
    add_index :rfid_readers, :key_lookup_digest, unique: true, where: 'key_lookup_digest IS NOT NULL',
                                               algorithm: :concurrently, if_not_exists: true

    scalar_email_digest_tables.each do |table, column|
      add_index table, column, algorithm: :concurrently, if_not_exists: true
    end
  end

  def remove_lookup_indexes
    scalar_email_digest_tables.each do |table, column|
      remove_index table, column: column, if_exists: true
    end
    remove_index :rfid_readers, column: :key_lookup_digest, if_exists: true
    remove_index :users, column: :extra_email_lookup_digests, if_exists: true
    remove_index :users, column: :email_lookup_digest, if_exists: true
  end

  def backfill_encrypted_values
    say_with_time 'Encrypting sensitive database fields and backfilling lookup digests' do
      encrypt_records(User, :email, :extra_emails, :mailing_address, :phone_number)
      encrypt_records(MembershipApplication, :email)
      encrypt_records(ApplicationVerification, :email)
      encrypt_records(Invitation, :email)
      encrypt_records(LocalAccount, :email)
      encrypt_records(SheetEntry, :email, :raw_attributes)
      encrypt_records(SlackUser, :email, :raw_attributes)
      encrypt_records(AuthentikUser, :email, :raw_attributes)
      encrypt_records(PaypalPayment, :payer_email, :raw_attributes)
      encrypt_records(RechargePayment, :customer_email, :raw_attributes)
      encrypt_records(KofiPayment, :email, :raw_attributes)
      encrypt_records(AccessController, :access_token, :environment_variables)
      encrypt_records(RfidReader, :key)
      encrypt_records(AiProvider, :api_key)
      encrypt_records(AiOllamaProfile, :api_key, :provider_api_key_override)
    end
  end

  def encrypt_records(model_class, *attributes)
    model_class.reset_column_information
    model_class.find_each do |record|
      attributes.each do |attribute|
        next unless record.has_attribute?(attribute)

        record.public_send("#{attribute}=", record.public_send(attribute))
      end
      record.save!(validate: false)
    end
  end
end
