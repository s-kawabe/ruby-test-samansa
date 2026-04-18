FactoryBot.define do
  factory :subscription_event do
    association :subscription
    event_type { "PURCHASE" }
    occurred_at { Time.current }
    amount { "3.99" }
    currency { "USD" }
    purchase_date { 1.month.ago }
    expires_date { 1.month.from_now }
  end
end
