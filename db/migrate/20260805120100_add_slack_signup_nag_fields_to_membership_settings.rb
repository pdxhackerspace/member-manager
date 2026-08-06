class AddSlackSignupNagFieldsToMembershipSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_settings, :slack_signup_nag_initial_delay_days, :integer,
               null: false, default: 7
    add_column :membership_settings, :slack_signup_nag_repeat_delay_days, :integer,
               null: false, default: 14
  end
end
