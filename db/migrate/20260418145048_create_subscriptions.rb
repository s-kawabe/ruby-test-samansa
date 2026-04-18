class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string :user_id, null: false
      t.string :transaction_id, null: false
      t.string :product_id, null: false
      t.string :store, null: false, default: "apple"
      t.string :status, null: false
      t.timestamptz :expires_date

      t.timestamps
    end

    add_index :subscriptions, :transaction_id, unique: true
    add_index :subscriptions, :user_id
    add_foreign_key :subscriptions, :plans, column: :product_id, primary_key: :product_id
  end
end
