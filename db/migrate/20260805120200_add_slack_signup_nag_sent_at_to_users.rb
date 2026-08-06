class AddSlackSignupNagSentAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_signup_nag_sent_at, :datetime
    add_index :users, :slack_signup_nag_sent_at
  end
end
