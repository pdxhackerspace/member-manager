class CreateMailLogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_log_entries do |t|
      t.references :queued_mail, foreign_key: true, null: false
      t.string :event, null: false
      t.references :actor, foreign_key: { to_table: :users }, null: true
      t.string :details
      t.timestamps
    end

    add_index :mail_log_entries, :event
    add_index :mail_log_entries, :created_at
  end
end
