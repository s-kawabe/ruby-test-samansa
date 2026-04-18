FactoryBot.define do
  factory :webhook_log do
    sequence(:notification_uuid) { |n| "uuid-#{n}" }
    notification_type { "PURCHASE" }
    transaction_id { "txn_1" }
    raw_payload { { type: "PURCHASE", transaction_id: "txn_1" } }
    processing_status { "pending" }
  end
end
