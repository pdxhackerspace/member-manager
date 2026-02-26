class AddMembershipTypeToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :invitations, :membership_type, :string, default: 'member', null: false
    add_index :invitations, :membership_type
  end
end
