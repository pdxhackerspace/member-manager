namespace :users do
  desc 'Update users with recent payments (within 32 days) to current dues and paying status when unknown'
  task update_recent_payments: :environment do
    cutoff_date = 32.days.ago.to_date
    updated_count = 0

    User.where.not(last_payment_date: nil)
        .where(last_payment_date: cutoff_date..)
        .find_each do |user|
      updates = {}
      updates[:dues_status] = 'current' unless user.dues_status == 'current'
      updates[:membership_status] = 'paying' if user.membership_status == 'unknown'

      next if updates.empty?

      Membership::ActiveStatus.assign_and_save!(user, updates)
      updated_count += 1
      puts "Updated #{user.display_name}: #{updates.inspect}"
    end

    puts "\nTotal users updated: #{updated_count}"
  end
end
