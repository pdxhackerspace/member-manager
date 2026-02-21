class CreatePaymentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_events do |t|
      t.references :user, foreign_key: true, null: true
      t.string :event_type, null: false
      t.string :source, null: false
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: 'USD'
      t.datetime :occurred_at, null: false
      t.string :external_id
      t.text :details
      t.references :paypal_payment, foreign_key: true, null: true
      t.references :recharge_payment, foreign_key: true, null: true
      t.references :kofi_payment, foreign_key: true, null: true
      t.references :cash_payment, foreign_key: true, null: true
      t.timestamps
    end

    add_index :payment_events, :event_type
    add_index :payment_events, :source
    add_index :payment_events, :occurred_at
    add_index :payment_events, :external_id
  end
end
