class CreateApplicationVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :application_verifications do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.boolean :confirmed_open_house, default: false, null: false
      t.boolean :confirmed_code_of_conduct, default: false, null: false
      t.boolean :email_verified, default: false, null: false
      t.datetime :expires_at, null: false
      t.datetime :verified_at

      t.timestamps
    end

    add_index :application_verifications, :token, unique: true
    add_index :application_verifications, :email
  end
end
