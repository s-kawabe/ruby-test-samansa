module Api
  module V1
    module Webhooks
      class ApplesController < ApplicationController
        def create
          existing = WebhookLog.find_by(notification_uuid: webhook_params[:notification_uuid])
          return head :ok if existing

          webhook_log = WebhookLog.create!(
            notification_uuid: webhook_params[:notification_uuid],
            notification_type: webhook_params[:type],
            transaction_id: webhook_params[:transaction_id],
            raw_payload: request.request_parameters,
            processing_status: "pending"
          )

          AppleWebhookProcessorJob.perform_later(webhook_log.id)
          head :ok
        end

        private

        def webhook_params
          params.permit(
            :notification_uuid,
            :type,
            :transaction_id,
            :product_id,
            :amount,
            :currency,
            :purchase_date,
            :expires_date
          )
        end
      end
    end
  end
end
