class AddSlackSignupNagMaxAccountAgeMonthsToMembershipSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_settings, :slack_signup_nag_max_account_age_months, :integer,
               default: 6, null: false
  end
end
