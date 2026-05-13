class AddDeliverySnapshotsToMailLogEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_log_entries, :delivery_body_html, :text
    add_column :mail_log_entries, :delivery_body_text, :text
  end
end
