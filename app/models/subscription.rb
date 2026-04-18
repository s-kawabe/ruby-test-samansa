class Subscription < ApplicationRecord
  STATUSES = %w[provisional active cancelled].freeze

  belongs_to :plan, foreign_key: :product_id, primary_key: :product_id, inverse_of: :subscriptions
  has_many :subscription_events, dependent: :restrict_with_error

  validates :user_id, presence: true
  validates :transaction_id, presence: true, uniqueness: true
  validates :product_id, presence: true
  validates :store, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
