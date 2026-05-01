class AddImmediateSendFlagsToEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :email_templates, :send_immediately, :boolean, default: false, null: false
    add_column :email_templates, :block_send_immediately, :boolean, default: false, null: false
  end
end
