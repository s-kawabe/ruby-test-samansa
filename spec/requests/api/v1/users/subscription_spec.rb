require "rails_helper"

RSpec.describe "GET /api/v1/users/:user_id/subscription", type: :request do
  let(:plan) { create(:plan) }
  let(:user_id) { "user_123" }

  def get_subscription
    get "/api/v1/users/#{user_id}/subscription"
  end

  context "サブスクリプションが存在しない" do
    it "viewable: false, status: null を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(false)
      expect(json["status"]).to be_nil
      expect(json["expires_at"]).to be_nil
    end
  end

  context "provisional（仮開始）" do
    before { create(:subscription, plan: plan, user_id: user_id, status: "provisional", expires_date: nil) }

    it "viewable: false を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(false)
      expect(json["status"]).to eq("provisional")
    end
  end

  context "active かつ期限内" do
    before { create(:subscription, plan: plan, user_id: user_id, status: "active", expires_date: 1.month.from_now) }

    it "viewable: true を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(true)
      expect(json["status"]).to eq("active")
      expect(json["expires_at"]).to be_present
    end
  end

  context "active かつ期限切れ" do
    before { create(:subscription, plan: plan, user_id: user_id, status: "active", expires_date: 1.day.ago) }

    it "viewable: false を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(false)
      expect(json["status"]).to eq("active")
    end
  end

  context "cancelled かつ期限内" do
    before { create(:subscription, plan: plan, user_id: user_id, status: "cancelled", expires_date: 1.month.from_now) }

    it "viewable: true を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(true)
      expect(json["status"]).to eq("cancelled")
      expect(json["expires_at"]).to be_present
    end
  end

  context "cancelled かつ期限切れ" do
    before { create(:subscription, plan: plan, user_id: user_id, status: "cancelled", expires_date: 1.day.ago) }

    it "viewable: false を返す" do
      get_subscription
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["viewable"]).to eq(false)
      expect(json["status"]).to eq("cancelled")
    end
  end
end
