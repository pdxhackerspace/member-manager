class AddApplicationVerificationExpiryToMembershipSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :membership_settings, :application_verification_expiry_hours, :integer, default: 24, null: false
  end
end
