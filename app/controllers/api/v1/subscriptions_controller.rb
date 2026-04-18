module Api
  module V1
    class SubscriptionsController < ApplicationController
      DEFAULT_STORE = "apple"
      PROVISIONAL_STATUS = "provisional"

      def create
        subscription = Subscription.find_or_initialize_by(transaction_id: subscription_params[:transaction_id])

        if upsertable?(subscription)
          subscription.assign_attributes(subscription_params.merge(store: DEFAULT_STORE, status: PROVISIONAL_STATUS))
          unless subscription.save
            render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
            return
          end
        end

        render json: { status: subscription.status }, status: :created
      end

      private

      def upsertable?(subscription)
        subscription.new_record? || subscription.status == PROVISIONAL_STATUS
      end

      def subscription_params
        params.permit(:user_id, :transaction_id, :product_id)
      end
    end
  end
end
