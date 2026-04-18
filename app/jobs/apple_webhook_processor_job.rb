class AppleWebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(webhook_log_id)
    webhook_log = WebhookLog.find(webhook_log_id)
    payload = webhook_log.raw_payload.with_indifferent_access

    ActiveRecord::Base.transaction do
      case webhook_log.notification_type
      when "PURCHASE" then process_purchase(payload)
      when "RENEW"    then process_renew(payload)
      when "CANCEL"   then process_cancel(payload)
      end

      webhook_log.update!(processing_status: "processed")
    end
  rescue => e
    webhook_log&.update!(processing_status: "failed", error_message: e.message)
    raise
  end

  private

  def process_purchase(payload)
    subscription = Subscription.find_or_initialize_by(transaction_id: payload[:transaction_id])
    subscription.assign_attributes(
      user_id: subscription.user_id.presence || payload[:transaction_id],
      product_id: payload[:product_id],
      status: "active",
      expires_date: payload[:expires_date]
    )
    subscription.save!
    record_event(subscription, "PURCHASE", payload)
  end

  def process_renew(payload)
    subscription = Subscription.find_by!(transaction_id: payload[:transaction_id])
    subscription.update!(expires_date: payload[:expires_date])
    record_event(subscription, "RENEW", payload)
  end

  def process_cancel(payload)
    subscription = Subscription.find_by!(transaction_id: payload[:transaction_id])
    subscription.update!(status: "cancelled")
    record_event(subscription, "CANCEL", payload)
  end

  def record_event(subscription, event_type, payload)
    subscription.subscription_events.create!(
      event_type: event_type,
      occurred_at: payload[:purchase_date].presence || Time.current,
      amount: payload[:amount],
      currency: payload[:currency],
      purchase_date: payload[:purchase_date],
      expires_date: payload[:expires_date]
    )
  end
end
