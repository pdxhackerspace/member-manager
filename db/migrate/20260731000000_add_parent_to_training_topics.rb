class AddParentToTrainingTopics < ActiveRecord::Migration[8.1]
  def change
    add_reference :training_topics, :parent, foreign_key: { to_table: :training_topics }, null: true
  end
end
