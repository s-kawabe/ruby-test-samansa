# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_18_145050) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "plans", primary_key: "product_id", id: :string, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "base_price", precision: 12, scale: 4, null: false
    t.integer "billing_period_months", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscription_events", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", limit: 3
    t.string "event_type", null: false
    t.timestamptz "expires_date"
    t.timestamptz "occurred_at", null: false
    t.timestamptz "purchase_date"
    t.bigint "subscription_id", null: false
    t.index ["subscription_id", "occurred_at"], name: "index_subscription_events_on_subscription_id_and_occurred_at"
    t.index ["subscription_id"], name: "index_subscription_events_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.timestamptz "expires_date"
    t.string "product_id", null: false
    t.string "status", null: false
    t.string "store", default: "apple", null: false
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["transaction_id"], name: "index_subscriptions_on_transaction_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "notification_type", null: false
    t.string "notification_uuid", null: false
    t.string "processing_status", default: "pending", null: false
    t.jsonb "raw_payload", null: false
    t.string "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["notification_uuid"], name: "index_webhook_logs_on_notification_uuid", unique: true
  end

  add_foreign_key "subscription_events", "subscriptions"
  add_foreign_key "subscriptions", "plans", column: "product_id", primary_key: "product_id"
end
