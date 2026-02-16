class RenameSponsoredToIsSponsored < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :sponsored, :is_sponsored
  end
end
