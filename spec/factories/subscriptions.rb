FactoryBot.define do
  factory :subscription do
    association :plan, strategy: :create
    sequence(:user_id) { |n| "user_#{n}" }
    sequence(:transaction_id) { |n| "txn_#{n}" }
    product_id { plan.product_id }
    store { "apple" }
    status { "provisional" }
    expires_date { nil }

    trait :active do
      status { "active" }
      expires_date { 1.month.from_now }
    end

    trait :cancelled do
      status { "cancelled" }
      expires_date { 1.month.from_now }
    end
  end
end
