# frozen_string_literal: true

RSpec.describe CMDx::Locale do
  describe ".t" do
    it "resolves known keys" do
      expect(described_class.t("cmdx.validators.presence")).to eq("cannot be empty")
      expect(described_class.t("cmdx.faults.invalid")).to eq("Invalid")
    end

    it "interpolates values" do
      msg = described_class.t("cmdx.coercions.into_a", type: "float")
      expect(msg).to include("float")
    end

    it "returns key for unknown paths" do
      expect(described_class.t("cmdx.unknown.key")).to eq("cmdx.unknown.key")
    end
  end
end
