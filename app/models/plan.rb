class Plan < ApplicationRecord
  self.primary_key = "product_id"

  has_many :subscriptions, foreign_key: :product_id, inverse_of: :plan

  validates :product_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :billing_period_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :base_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, length: { is: 3 }
end
