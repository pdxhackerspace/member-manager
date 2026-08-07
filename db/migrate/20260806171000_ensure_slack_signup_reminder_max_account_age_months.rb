class EnsureSlackSignupReminderMaxAccountAgeMonths < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:membership_settings, :slack_signup_reminder_max_account_age_months)

    if column_exists?(:membership_settings, :slack_signup_nag_max_account_age_months)
      rename_column :membership_settings, :slack_signup_nag_max_account_age_months,
                    :slack_signup_reminder_max_account_age_months
    else
      add_column :membership_settings, :slack_signup_reminder_max_account_age_months, :integer,
                 null: false, default: 6
    end
  end

  def down
    return unless column_exists?(:membership_settings, :slack_signup_reminder_max_account_age_months)
    return if column_exists?(:membership_settings, :slack_signup_nag_max_account_age_months)

    remove_column :membership_settings, :slack_signup_reminder_max_account_age_months
  end
end
