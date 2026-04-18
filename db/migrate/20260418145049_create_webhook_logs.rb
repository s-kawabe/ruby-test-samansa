class CreateWebhookLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_logs do |t|
      t.string :notification_uuid, null: false
      t.string :notification_type, null: false
      t.string :transaction_id
      t.jsonb :raw_payload, null: false
      t.string :processing_status, null: false, default: "pending"
      t.text :error_message

      t.timestamps
    end

    add_index :webhook_logs, :notification_uuid, unique: true
  end
end
