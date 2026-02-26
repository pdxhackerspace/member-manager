class AddInvitationExpiryToMembershipSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_settings, :invitation_expiry_hours, :integer, default: 72, null: false
  end
end
