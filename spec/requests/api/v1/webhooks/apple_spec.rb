require "rails_helper"

RSpec.describe "POST /api/v1/webhooks/apple", type: :request do
  include ActiveJob::TestHelper

  let(:valid_params) do
    {
      notification_uuid: "uuid-test-001",
      type: "PURCHASE",
      transaction_id: "txn_abc123",
      product_id: "com.example.premium",
      amount: "3.9",
      currency: "USD",
      purchase_date: "2025-10-01T12:00:00Z",
      expires_date: "2025-11-01T12:00:00Z"
    }
  end

  describe "正常系" do
    it "新規 notification_uuid で 200 OK を返す" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "webhook_logs に1件 INSERT される" do
      expect {
        post "/api/v1/webhooks/apple", params: valid_params.to_json,
          headers: { "Content-Type" => "application/json" }
      }.to change(WebhookLog, :count).by(1)
    end

    it "notification_type に type の値がマッピングされる" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      log = WebhookLog.last
      expect(log.notification_type).to eq("PURCHASE")
    end

    it "raw_payload にリクエストボディ全体が保存される" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      log = WebhookLog.last
      expect(log.raw_payload["notification_uuid"]).to eq("uuid-test-001")
      expect(log.raw_payload["transaction_id"]).to eq("txn_abc123")
    end

    it "processing_status が pending で保存される" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      log = WebhookLog.last
      expect(log.processing_status).to eq("pending")
    end

    it "AppleWebhookProcessorJob がエンキューされる" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      log = WebhookLog.last
      expect(AppleWebhookProcessorJob).to have_been_enqueued.with(log.id)
    end
  end

  describe "冪等性" do
    before do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }
    end

    it "同じ notification_uuid を2回送ると 200 OK を返す" do
      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "2回目は webhook_logs が増えない" do
      expect {
        post "/api/v1/webhooks/apple", params: valid_params.to_json,
          headers: { "Content-Type" => "application/json" }
      }.not_to change(WebhookLog, :count)
    end

    it "2回目は AppleWebhookProcessorJob が追加エンキューされない" do
      clear_enqueued_jobs

      post "/api/v1/webhooks/apple", params: valid_params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(AppleWebhookProcessorJob).not_to have_been_enqueued
    end
  end
end
