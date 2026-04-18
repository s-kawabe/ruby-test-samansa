class CreateSubscriptionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_events do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :event_type, null: false
      t.timestamptz :occurred_at, null: false
      t.decimal :amount, precision: 12, scale: 4
      t.string :currency, limit: 3
      t.timestamptz :purchase_date
      t.timestamptz :expires_date

      t.datetime :created_at, null: false
    end

    add_index :subscription_events, [ :subscription_id, :occurred_at ]
  end
end
