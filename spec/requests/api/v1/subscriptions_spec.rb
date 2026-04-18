require "rails_helper"

RSpec.describe "POST /api/v1/subscriptions", type: :request do
  let(:plan) { create(:plan) }
  let(:valid_params) do
    {
      user_id: "user_001",
      transaction_id: "txn_abc123",
      product_id: plan.product_id
    }
  end

  describe "正常系" do
    it "201 Created と status: provisional を返す" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("status" => "provisional")
    end

    it "Subscription レコードが作成される" do
      expect {
        post "/api/v1/subscriptions", params: valid_params, as: :json
      }.to change(Subscription, :count).by(1)
    end

    it "作成された Subscription の status が provisional になる" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      subscription = Subscription.find_by(transaction_id: "txn_abc123")
      expect(subscription.status).to eq("provisional")
    end

    it "store がデフォルト apple になる" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      subscription = Subscription.find_by(transaction_id: "txn_abc123")
      expect(subscription.store).to eq("apple")
    end
  end

  describe "重複リクエスト（同一 transaction_id が provisional の場合）" do
    before do
      create(:subscription, transaction_id: "txn_abc123", product_id: plan.product_id, status: "provisional")
    end

    it "201 Created と status: provisional を返す" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("status" => "provisional")
    end

    it "新たな Subscription レコードは作成されない" do
      expect {
        post "/api/v1/subscriptions", params: valid_params, as: :json
      }.not_to change(Subscription, :count)
    end
  end

  describe "Webhook先着ケース（同一 transaction_id が既に active の場合）" do
    before do
      create(:subscription, transaction_id: "txn_abc123", product_id: plan.product_id, status: "active")
    end

    it "201 Created と status: active を返す（provisional に戻さない）" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("status" => "active")
    end

    it "Subscription の status が active のまま変わらない" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      subscription = Subscription.find_by(transaction_id: "txn_abc123")
      expect(subscription.status).to eq("active")
    end
  end

  describe "Webhook先着ケース（同一 transaction_id が cancelled の場合）" do
    before do
      create(:subscription, transaction_id: "txn_abc123", product_id: plan.product_id, status: "cancelled")
    end

    it "201 Created と status: cancelled を返す（provisional に戻さない）" do
      post "/api/v1/subscriptions", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("status" => "cancelled")
    end
  end

  describe "異常系" do
    context "user_id が空の場合" do
      it "422 Unprocessable Entity を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.merge(user_id: ""),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to have_key("errors")
      end
    end

    context "transaction_id が空の場合" do
      it "422 Unprocessable Entity を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.merge(transaction_id: ""),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to have_key("errors")
      end
    end

    context "product_id が存在しない plan の場合" do
      it "422 Unprocessable Entity を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.merge(product_id: "nonexistent.product"),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to have_key("errors")
      end
    end

    context "必須パラメータが欠けている場合" do
      it "user_id がない場合に 422 を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.except(:user_id),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "transaction_id がない場合に 422 を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.except(:transaction_id),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "product_id がない場合に 422 を返す" do
        post "/api/v1/subscriptions",
             params: valid_params.except(:product_id),
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
