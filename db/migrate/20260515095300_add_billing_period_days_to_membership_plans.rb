class AddBillingPeriodDaysToMembershipPlans < ActiveRecord::Migration[8.1]
  def up
    add_column :membership_plans, :billing_period_days, :integer

    execute <<~SQL.squish
      UPDATE membership_plans
      SET billing_period_days = CASE billing_frequency
        WHEN 'yearly' THEN 365
        ELSE 30
      END,
      billing_frequency = 'custom_days'
      WHERE user_id IS NOT NULL
    SQL
  end

  def down
    remove_column :membership_plans, :billing_period_days
  end
end
