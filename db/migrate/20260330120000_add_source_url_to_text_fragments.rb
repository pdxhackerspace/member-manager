class AddSourceUrlToTextFragments < ActiveRecord::Migration[8.1]
  def change
    add_column :text_fragments, :source_url, :string
  end
end
