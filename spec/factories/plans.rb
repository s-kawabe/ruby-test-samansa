FactoryBot.define do
  factory :plan do
    sequence(:product_id) { |n| "com.samansa.subscription.plan#{n}" }
    name { "月額プラン" }
    billing_period_months { 1 }
    base_price { "3.99" }
    currency { "USD" }
    active { true }
  end
end
