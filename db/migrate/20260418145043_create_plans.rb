class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans, primary_key: :product_id, id: :string, force: :cascade do |t|
      t.string :name, null: false
      t.integer :billing_period_months, null: false
      t.decimal :base_price, precision: 12, scale: 4, null: false
      t.string :currency, limit: 3, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
