# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Absence do
  describe ".call" do
    let(:message) { CMDx::Locale.t("cmdx.validators.absence") }

    it "returns nil for nil" do
      expect(described_class.call(nil)).to be_nil
    end

    it "returns nil for an empty string" do
      expect(described_class.call("")).to be_nil
    end

    it "returns an error when a value is present" do
      expect(described_class.call("x")).to eq(message)
      expect(described_class.call([1])).to eq(message)
    end
  end
end
