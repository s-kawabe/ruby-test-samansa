require "rails_helper"

RSpec.describe SubscriptionEvent, type: :model do
  describe "validations" do
    subject { build(:subscription_event) }

    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:occurred_at) }
    it { is_expected.to validate_inclusion_of(:event_type).in_array(%w[PURCHASE RENEW CANCEL]) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:subscription) }
  end
end
