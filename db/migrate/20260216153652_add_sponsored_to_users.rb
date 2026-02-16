class AddSponsoredToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sponsored, :boolean, default: false, null: false
    add_index :users, :sponsored
  end
end
