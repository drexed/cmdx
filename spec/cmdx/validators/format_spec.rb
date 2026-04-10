# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Format do
  describe ".call" do
    let(:pattern) { /\A[a-z]+\z/ }
    let(:message) { CMDx::Locale.t("cmdx.validators.format") }

    it "returns nil when the value matches" do
      expect(described_class.call("abc", with: pattern)).to be_nil
    end

    it "returns an error when the value does not match" do
      expect(described_class.call("Abc", with: pattern)).to eq(message)
    end

    it "skips validation when value is nil" do
      expect(described_class.call(nil, with: pattern)).to be_nil
    end
  end
end
