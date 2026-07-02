class AddDismissedAtToTrainingRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :training_requests, :dismissed_at, :datetime
    add_index :training_requests, :dismissed_at
  end
end
