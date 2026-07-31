class AddLoginKeyfobSignInEnabledToDefaultSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :default_settings, :login_keyfob_sign_in_enabled, :boolean, default: true, null: false
  end
end
