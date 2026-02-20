class CreateQueuedMails < ActiveRecord::Migration[8.1]
  def change
    create_table :queued_mails do |t|
      t.string :to, null: false
      t.string :subject, null: false
      t.text :body_html, null: false
      t.text :body_text
      t.string :reason, null: false
      t.references :email_template, foreign_key: true, null: true
      t.string :mailer_action, null: false
      t.references :recipient, foreign_key: { to_table: :users }, null: true
      t.jsonb :mailer_args, default: {}
      t.string :status, null: false, default: 'pending'
      t.references :reviewed_by, foreign_key: { to_table: :users }, null: true
      t.datetime :reviewed_at
      t.datetime :sent_at
      t.timestamps
    end

    add_index :queued_mails, :status
  end
end
