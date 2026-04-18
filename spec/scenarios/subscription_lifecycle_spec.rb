require "rails_helper"

RSpec.describe "サブスクリプションライフサイクル", type: :request do
  include ActiveJob::TestHelper

  let(:plan) { create(:plan) }
  let(:user_id) { "user_scenario_1" }
  let(:transaction_id) { "txn_scenario_1" }

  let(:purchase_webhook_params) do
    {
      notification_uuid: "uuid-purchase-1",
      type: "PURCHASE",
      transaction_id: transaction_id,
      product_id: plan.product_id,
      amount: "3.99",
      currency: "USD",
      purchase_date: 1.day.ago.iso8601,
      expires_date: 1.month.from_now.iso8601
    }
  end

  def viewable_response
    get "/api/v1/users/#{user_id}/subscription"
    response.parsed_body
  end

  # 正常系: 仮開始 → PURCHASE → RENEW → CANCEL → 期限切れ
  describe "正常系フロー" do
    it "仮開始→視聴不可、PURCHASE後→視聴可能" do
      # 1. クライアントが仮開始
      post "/api/v1/subscriptions", params: {
        user_id: user_id,
        transaction_id: transaction_id,
        product_id: plan.product_id
      }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("provisional")

      # 2. 仮開始中は視聴不可
      expect(viewable_response["viewable"]).to eq(false)
      expect(viewable_response["status"]).to eq("provisional")

      # 3. Apple から PURCHASE Webhook
      post "/api/v1/webhooks/apple", params: purchase_webhook_params
      expect(response).to have_http_status(:ok)

      # 4. Job 実行
      perform_enqueued_jobs

      # 5. active になり視聴可能
      result = viewable_response
      expect(result["viewable"]).to eq(true)
      expect(result["status"]).to eq("active")
      expect(result["expires_at"]).to be_present
    end

    it "RENEW で expires_date が延長される" do
      post "/api/v1/subscriptions", params: {
        user_id: user_id, transaction_id: transaction_id, product_id: plan.product_id
      }
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: purchase_webhook_params
      end

      original_expires_at = viewable_response["expires_at"]

      # RENEW Webhook
      new_expires = 2.months.from_now
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: {
          notification_uuid: "uuid-renew-1",
          type: "RENEW",
          transaction_id: transaction_id,
          product_id: plan.product_id,
          amount: "3.99",
          currency: "USD",
          purchase_date: Time.current.iso8601,
          expires_date: new_expires.iso8601
        }
      end

      result = viewable_response
      expect(result["viewable"]).to eq(true)
      expect(result["status"]).to eq("active")
      expect(Time.parse(result["expires_at"])).to be > Time.parse(original_expires_at)
    end

    it "CANCEL 後も expires_date まで視聴可能、期限切れで視聴不可" do
      post "/api/v1/subscriptions", params: {
        user_id: user_id, transaction_id: transaction_id, product_id: plan.product_id
      }
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: purchase_webhook_params
      end

      # CANCEL Webhook
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: {
          notification_uuid: "uuid-cancel-1",
          type: "CANCEL",
          transaction_id: transaction_id,
          product_id: plan.product_id,
          expires_date: 1.month.from_now.iso8601
        }
      end

      # expires_date 内は視聴可能
      result = viewable_response
      expect(result["viewable"]).to eq(true)
      expect(result["status"]).to eq("cancelled")

      # expires_date を過去に強制更新して期限切れを再現
      Subscription.find_by(transaction_id: transaction_id).update_columns(expires_date: 1.day.ago)

      result = viewable_response
      expect(result["viewable"]).to eq(false)
      expect(result["status"]).to eq("cancelled")
    end
  end

  # Webhook先着ケース: Webhook が仮開始より先に届く
  describe "Webhook先着フロー" do
    it "PURCHASE Webhook が先着しても active で作成され、後からの仮開始でも active を維持する" do
      # 1. Webhook が先に到達（subscriptions レコードなし）
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: purchase_webhook_params.merge(
          notification_uuid: "uuid-early-1"
        )
      end

      subscription = Subscription.find_by(transaction_id: transaction_id)
      expect(subscription).to be_present
      expect(subscription.status).to eq("active")

      # 2. 後からクライアントの仮開始リクエストが届く
      post "/api/v1/subscriptions", params: {
        user_id: user_id,
        transaction_id: transaction_id,
        product_id: plan.product_id
      }
      expect(response).to have_http_status(:created)

      # 3. active のまま（provisional に戻らない）
      expect(response.parsed_body["status"]).to eq("active")
      expect(subscription.reload.status).to eq("active")
    end
  end

  # 冪等性: 同一 Webhook の再送
  describe "Webhook冪等性" do
    it "同一 notification_uuid の再送は無視される" do
      post "/api/v1/subscriptions", params: {
        user_id: user_id, transaction_id: transaction_id, product_id: plan.product_id
      }

      # 1回目
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: purchase_webhook_params
      end
      expect(WebhookLog.count).to eq(1)

      # 2回目（同一 notification_uuid）
      perform_enqueued_jobs do
        post "/api/v1/webhooks/apple", params: purchase_webhook_params
      end

      # webhook_logs が増えていない
      expect(WebhookLog.count).to eq(1)
      # subscription_events も1件のまま
      expect(SubscriptionEvent.count).to eq(1)
    end
  end
end
