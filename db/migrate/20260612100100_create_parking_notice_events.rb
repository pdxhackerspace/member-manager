class CreateParkingNoticeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :parking_notice_events do |t|
      t.references :parking_notice, null: false, foreign_key: true
      t.references :actor, null: true, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.text :note
      t.timestamps
    end

    add_index :parking_notice_events, %i[parking_notice_id created_at]
    add_index :parking_notice_events, :event_type
  end
end
