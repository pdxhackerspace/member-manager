class AddNeedsReviewToEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :email_templates, :needs_review, :boolean, default: true, null: false
    add_index :email_templates, :needs_review
  end
end
