class RenameNagsToRemindersAndAddApplicationLinkReminders < ActiveRecord::Migration[8.1]
  def up
    rename_table :nag_settings, :reminder_settings if table_exists?(:nag_settings)

    if column_exists?(:membership_settings, :slack_signup_nag_initial_delay_days)
      rename_column :membership_settings, :slack_signup_nag_initial_delay_days,
                      :slack_signup_reminder_initial_delay_days
    end
    if column_exists?(:membership_settings, :slack_signup_nag_repeat_delay_days)
      rename_column :membership_settings, :slack_signup_nag_repeat_delay_days,
                      :slack_signup_reminder_repeat_delay_days
    end
    if column_exists?(:membership_settings, :slack_signup_nag_max_account_age_months)
      rename_column :membership_settings, :slack_signup_nag_max_account_age_months,
                      :slack_signup_reminder_max_account_age_months
    end

    unless column_exists?(:membership_settings, :application_link_reminder_delay_days)
      add_column :membership_settings, :application_link_reminder_delay_days, :integer, null: false, default: 3
    end
    unless column_exists?(:membership_settings, :application_link_reminder_max_count)
      add_column :membership_settings, :application_link_reminder_max_count, :integer, null: false, default: 3
    end

    if column_exists?(:users, :slack_signup_nag_sent_at)
      rename_column :users, :slack_signup_nag_sent_at, :slack_signup_reminder_sent_at
    end
    if index_exists?(:users, :slack_signup_nag_sent_at, name: 'index_users_on_slack_signup_nag_sent_at')
      rename_index :users, 'index_users_on_slack_signup_nag_sent_at',
                   'index_users_on_slack_signup_reminder_sent_at'
    end

    if column_exists?(:membership_applications, :application_nag_sent_at)
      rename_column :membership_applications, :application_nag_sent_at, :application_reminder_sent_at
    end
    if index_exists?(:membership_applications, :application_nag_sent_at,
                     name: 'index_membership_applications_on_application_nag_sent_at')
      rename_index :membership_applications, 'index_membership_applications_on_application_nag_sent_at',
                   'index_membership_applications_on_application_reminder_sent_at'
    end

    unless column_exists?(:application_verifications, :application_link_reminder_count)
      add_column :application_verifications, :application_link_reminder_count, :integer, null: false, default: 0
    end
    unless column_exists?(:application_verifications, :application_link_reminder_sent_at)
      add_column :application_verifications, :application_link_reminder_sent_at, :datetime
    end

    rename_email_template_key('slack_signup_nag', 'slack_signup_reminder')
    rename_email_template_key('staff_application_nag', 'staff_application_reminder')

    seed_application_link_reminder_setting
    seed_application_link_reminder_template
  end

  def down
    EmailTemplate.where(key: 'application_link_reminder').delete_all
    execute("DELETE FROM reminder_settings WHERE key = 'application_link'") if table_exists?(:reminder_settings)

    rename_email_template_key('slack_signup_reminder', 'slack_signup_nag')
    rename_email_template_key('staff_application_reminder', 'staff_application_nag')

    remove_column :application_verifications, :application_link_reminder_sent_at if column_exists?(
      :application_verifications, :application_link_reminder_sent_at
    )
    remove_column :application_verifications, :application_link_reminder_count if column_exists?(
      :application_verifications, :application_link_reminder_count
    )

    if index_exists?(:membership_applications, :application_reminder_sent_at,
                     name: 'index_membership_applications_on_application_reminder_sent_at')
      rename_index :membership_applications, 'index_membership_applications_on_application_reminder_sent_at',
                   'index_membership_applications_on_application_nag_sent_at'
    end
    if column_exists?(:membership_applications, :application_reminder_sent_at)
      rename_column :membership_applications, :application_reminder_sent_at, :application_nag_sent_at
    end

    if index_exists?(:users, :slack_signup_reminder_sent_at, name: 'index_users_on_slack_signup_reminder_sent_at')
      rename_index :users, 'index_users_on_slack_signup_reminder_sent_at', 'index_users_on_slack_signup_nag_sent_at'
    end
    if column_exists?(:users, :slack_signup_reminder_sent_at)
      rename_column :users, :slack_signup_reminder_sent_at, :slack_signup_nag_sent_at
    end

    remove_column :membership_settings, :application_link_reminder_max_count if column_exists?(
      :membership_settings, :application_link_reminder_max_count
    )
    remove_column :membership_settings, :application_link_reminder_delay_days if column_exists?(
      :membership_settings, :application_link_reminder_delay_days
    )

    if column_exists?(:membership_settings, :slack_signup_reminder_repeat_delay_days)
      rename_column :membership_settings, :slack_signup_reminder_repeat_delay_days,
                      :slack_signup_nag_repeat_delay_days
    end
    if column_exists?(:membership_settings, :slack_signup_reminder_max_account_age_months)
      rename_column :membership_settings, :slack_signup_reminder_max_account_age_months,
                      :slack_signup_nag_max_account_age_months
    end
    if column_exists?(:membership_settings, :slack_signup_reminder_initial_delay_days)
      rename_column :membership_settings, :slack_signup_reminder_initial_delay_days,
                      :slack_signup_nag_initial_delay_days
    end

    rename_table :reminder_settings, :nag_settings if table_exists?(:reminder_settings)
  end

  private

  def rename_email_template_key(from_key, to_key)
    return unless EmailTemplate.exists?(key: from_key)
    return if EmailTemplate.exists?(key: to_key)

    EmailTemplate.where(key: from_key).update_all(key: to_key)
  end

  def seed_application_link_reminder_setting
    return unless table_exists?(:reminder_settings)

    attrs = ReminderSetting::CATALOG.fetch('application_link')
    ReminderSetting.find_or_create_by!(key: 'application_link') do |setting|
      setting.assign_attributes(attrs)
    end
  end

  def seed_application_link_reminder_template
    return if EmailTemplate.exists?(key: 'application_link_reminder')

    attrs = EmailTemplate::DEFAULT_TEMPLATES.fetch('application_link_reminder')
    EmailTemplate.create!({ key: 'application_link_reminder' }.merge(attrs))
  end
end
