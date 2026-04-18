class SubscriptionEvent < ApplicationRecord
  EVENT_TYPES = %w[PURCHASE RENEW CANCEL].freeze

  self.ignored_columns += ["updated_at"]

  belongs_to :subscription

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
end
