class AddOutcomeEmailToMembershipApplications < ActiveRecord::Migration[8.1]
  def change
    change_table :membership_applications, bulk: true do |t|
      t.references :outcome_queued_mail, foreign_key: { to_table: :queued_mails }
      t.string :outcome_email_subject
      t.text :outcome_email_body_html
    end
  end
end
