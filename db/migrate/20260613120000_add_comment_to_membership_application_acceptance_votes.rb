class AddCommentToMembershipApplicationAcceptanceVotes < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_application_acceptance_votes, :comment, :text
  end
end
