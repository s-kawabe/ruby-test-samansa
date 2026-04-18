require "rails_helper"

RSpec.describe WebhookLog, type: :model do
  describe "validations" do
    subject { build(:webhook_log) }

    it { is_expected.to validate_presence_of(:notification_uuid) }
    it { is_expected.to validate_presence_of(:notification_type) }
    it { is_expected.to validate_presence_of(:raw_payload) }
    it { is_expected.to validate_presence_of(:processing_status) }
    it { is_expected.to validate_uniqueness_of(:notification_uuid) }
    it { is_expected.to validate_inclusion_of(:notification_type).in_array(%w[PURCHASE RENEW CANCEL]) }
    it { is_expected.to validate_inclusion_of(:processing_status).in_array(%w[pending processed failed]) }
  end
end
