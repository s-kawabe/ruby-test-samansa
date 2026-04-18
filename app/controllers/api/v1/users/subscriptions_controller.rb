module Api
  module V1
    module Users
      class SubscriptionsController < ApplicationController
        def show
          subscription = Subscription.find_by(user_id: params[:user_id])
          render json: serialize(subscription)
        end

        private

        def serialize(subscription)
          return { viewable: false, status: nil, expires_at: nil } if subscription.nil?

          viewable = %w[active cancelled].include?(subscription.status) &&
                     subscription.expires_date.present? &&
                     subscription.expires_date > Time.current

          {
            viewable: viewable,
            status: subscription.status,
            expires_at: subscription.expires_date&.iso8601
          }
        end
      end
    end
  end
end
