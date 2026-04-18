Plan.find_or_create_by!(product_id: "com.samansa.subscription.monthly") do |plan|
  plan.name = "月額プラン"
  plan.billing_period_months = 1
  plan.base_price = 3.99
  plan.currency = "USD"
end

Plan.find_or_create_by!(product_id: "com.samansa.subscription.yearly") do |plan|
  plan.name = "年額プラン"
  plan.billing_period_months = 12
  plan.base_price = 39.99
  plan.currency = "USD"
end
