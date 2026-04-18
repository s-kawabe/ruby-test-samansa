class WebhookLog < ApplicationRecord
  NOTIFICATION_TYPES = %w[PURCHASE RENEW CANCEL].freeze
  PROCESSING_STATUSES = %w[pending processed failed].freeze

  validates :notification_uuid, presence: true, uniqueness: true
  validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES }
  validates :raw_payload, presence: true
  validates :processing_status, presence: true, inclusion: { in: PROCESSING_STATUSES }
end
