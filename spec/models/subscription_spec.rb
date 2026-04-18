require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "validations" do
    subject { build(:subscription) }

    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:transaction_id) }
    it { is_expected.to validate_presence_of(:product_id) }
    it { is_expected.to validate_presence_of(:store) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_uniqueness_of(:transaction_id) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[provisional active cancelled]) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:plan).with_foreign_key(:product_id).with_primary_key(:product_id) }
    it { is_expected.to have_many(:subscription_events) }
  end

  describe "defaults" do
    it "sets store to apple by default" do
      expect(Subscription.new.store).to eq("apple")
    end
  end
end
