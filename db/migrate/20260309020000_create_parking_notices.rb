class CreateParkingNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :parking_notices do |t|
      t.string :notice_type, null: false
      t.string :status, null: false, default: 'active'
      t.references :user, null: true, foreign_key: true
      t.references :issued_by, null: false, foreign_key: { to_table: :users }
      t.text :description
      t.string :location
      t.string :location_detail
      t.datetime :expires_at, null: false
      t.datetime :cleared_at
      t.references :cleared_by, null: true, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end

    add_index :parking_notices, %i[notice_type status]
    add_index :parking_notices, :expires_at
    add_index :parking_notices, :status
  end
end
