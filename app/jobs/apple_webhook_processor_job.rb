class AppleWebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(webhook_log_id)
  end
end
