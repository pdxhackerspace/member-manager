class AddApplicationReviewTimeCapDaysToMembershipSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_settings, :application_review_time_cap_days, :integer, default: 15, null: false
  end
end
