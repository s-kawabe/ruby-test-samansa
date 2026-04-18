require "rails_helper"

RSpec.describe AppleWebhookProcessorJob, type: :job do
  let(:plan) { create(:plan) }

  describe "PURCHASE" do
    context "仮開始レコードあり" do
      let(:subscription) { create(:subscription, plan: plan, status: "provisional", expires_date: nil) }
      let(:webhook_log) do
        create(:webhook_log,
          notification_type: "PURCHASE",
          transaction_id: subscription.transaction_id,
          raw_payload: {
            notification_uuid: "uuid-1",
            type: "PURCHASE",
            transaction_id: subscription.transaction_id,
            product_id: plan.product_id,
            amount: "3.99",
            currency: "USD",
            purchase_date: "2025-10-01T12:00:00Z",
            expires_date: "2025-11-01T12:00:00Z"
          })
      end

      it "active に遷移し expires_date をセットする" do
        described_class.perform_now(webhook_log.id)
        expect(subscription.reload.status).to eq("active")
        expect(subscription.reload.expires_date).to be_present
      end

      it "subscription_events に PURCHASE を記録する" do
        expect { described_class.perform_now(webhook_log.id) }
          .to change { subscription.subscription_events.count }.by(1)
        event = subscription.subscription_events.last
        expect(event.event_type).to eq("PURCHASE")
        expect(event.amount).to eq(BigDecimal("3.99"))
        expect(event.currency).to eq("USD")
      end

      it "webhook_log を processed に更新する" do
        described_class.perform_now(webhook_log.id)
        expect(webhook_log.reload.processing_status).to eq("processed")
      end
    end

    context "レコードなし（Webhook先着）" do
      let(:webhook_log) do
        create(:webhook_log,
          notification_type: "PURCHASE",
          transaction_id: "txn_new",
          raw_payload: {
            notification_uuid: "uuid-2",
            type: "PURCHASE",
            transaction_id: "txn_new",
            product_id: plan.product_id,
            amount: "3.99",
            currency: "USD",
            purchase_date: "2025-10-01T12:00:00Z",
            expires_date: "2025-11-01T12:00:00Z"
          })
      end

      it "active で新規作成する" do
        expect { described_class.perform_now(webhook_log.id) }
          .to change(Subscription, :count).by(1)
        sub = Subscription.find_by(transaction_id: "txn_new")
        expect(sub.status).to eq("active")
        expect(sub.expires_date).to be_present
      end

      it "subscription_events に PURCHASE を記録する" do
        described_class.perform_now(webhook_log.id)
        sub = Subscription.find_by(transaction_id: "txn_new")
        expect(sub.subscription_events.count).to eq(1)
        expect(sub.subscription_events.last.event_type).to eq("PURCHASE")
      end

      it "webhook_log を processed に更新する" do
        described_class.perform_now(webhook_log.id)
        expect(webhook_log.reload.processing_status).to eq("processed")
      end
    end
  end

  describe "RENEW" do
    let(:expires_date) { 1.month.from_now }
    let(:new_expires_date) { 2.months.from_now.iso8601 }
    let(:subscription) { create(:subscription, plan: plan, status: "active", expires_date: expires_date) }
    let(:webhook_log) do
      create(:webhook_log,
        notification_type: "RENEW",
        transaction_id: subscription.transaction_id,
        raw_payload: {
          notification_uuid: "uuid-3",
          type: "RENEW",
          transaction_id: subscription.transaction_id,
          product_id: plan.product_id,
          amount: "3.99",
          currency: "USD",
          purchase_date: Time.current.iso8601,
          expires_date: new_expires_date
        })
    end

    it "expires_date を延長する" do
      described_class.perform_now(webhook_log.id)
      expect(subscription.reload.expires_date).to be > expires_date
    end

    it "subscription_events に RENEW を記録する" do
      expect { described_class.perform_now(webhook_log.id) }
        .to change { subscription.subscription_events.count }.by(1)
      expect(subscription.subscription_events.last.event_type).to eq("RENEW")
    end

    it "webhook_log を processed に更新する" do
      described_class.perform_now(webhook_log.id)
      expect(webhook_log.reload.processing_status).to eq("processed")
    end
  end

  describe "CANCEL" do
    let(:expires_date) { 1.month.from_now }
    let(:subscription) { create(:subscription, plan: plan, status: "active", expires_date: expires_date) }
    let(:webhook_log) do
      create(:webhook_log,
        notification_type: "CANCEL",
        transaction_id: subscription.transaction_id,
        raw_payload: {
          notification_uuid: "uuid-4",
          type: "CANCEL",
          transaction_id: subscription.transaction_id,
          product_id: plan.product_id,
          expires_date: expires_date.iso8601
        })
    end

    it "cancelled に遷移する" do
      described_class.perform_now(webhook_log.id)
      expect(subscription.reload.status).to eq("cancelled")
    end

    it "expires_date を変更しない" do
      described_class.perform_now(webhook_log.id)
      expect(subscription.reload.expires_date).to be_within(1.second).of(expires_date)
    end

    it "subscription_events に CANCEL を記録する" do
      expect { described_class.perform_now(webhook_log.id) }
        .to change { subscription.subscription_events.count }.by(1)
      expect(subscription.subscription_events.last.event_type).to eq("CANCEL")
    end

    it "webhook_log を processed に更新する" do
      described_class.perform_now(webhook_log.id)
      expect(webhook_log.reload.processing_status).to eq("processed")
    end
  end
end
