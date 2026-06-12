class AddClearanceFieldsToParkingNotices < ActiveRecord::Migration[8.1]
  def change
    add_column :parking_notices, :requires_admin_clearance, :boolean, null: false, default: false
    add_column :parking_notices, :clearance_requested_at, :datetime
    add_reference :parking_notices, :clearance_requested_by,
                  null: true, foreign_key: { to_table: :users }

    add_index :parking_notices, :requires_admin_clearance
    add_index :parking_notices, :clearance_requested_at
  end
end
