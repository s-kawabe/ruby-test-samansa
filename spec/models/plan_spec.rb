require "rails_helper"

RSpec.describe Plan, type: :model do
  describe "validations" do
    subject { build(:plan) }

    it { is_expected.to validate_presence_of(:product_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:billing_period_months) }
    it { is_expected.to validate_presence_of(:base_price) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_numericality_of(:billing_period_months).is_greater_than(0).only_integer }
    it { is_expected.to validate_numericality_of(:base_price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_length_of(:currency).is_equal_to(3) }
    it { is_expected.to validate_uniqueness_of(:product_id) }
  end

  describe "associations" do
    it { is_expected.to have_many(:subscriptions).with_foreign_key(:product_id) }
  end

  describe "defaults" do
    it "sets active to true by default" do
      expect(Plan.new.active).to eq(true)
    end
  end
end
