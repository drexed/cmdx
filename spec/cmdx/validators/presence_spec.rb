# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  describe ".call" do
    let(:message) { CMDx::Locale.t("cmdx.validators.presence") }

    it "returns an error for nil" do
      expect(described_class.call(nil)).to eq(message)
    end

    it "returns an error for an empty string" do
      expect(described_class.call("")).to eq(message)
    end

    it "returns nil when present" do
      expect(described_class.call("a")).to be_nil
      expect(described_class.call([1])).to be_nil
      expect(described_class.call(0)).to be_nil
    end
  end
end
