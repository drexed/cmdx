# frozen_string_literal: true

RSpec.describe CMDx::Messages do
  describe ".resolve" do
    it "resolves a known template" do
      expect(described_class.resolve("attribute.required")).to eq("is required")
    end

    it "interpolates values" do
      msg = described_class.resolve("coercion.single", type: :integer)
      expect(msg).to eq("could not coerce into integer")
    end

    it "returns the key for unknown templates" do
      expect(described_class.resolve("unknown.key")).to eq("unknown.key")
    end

    it "delegates to custom resolver when set" do
      CMDx.message_resolver = ->(key, **opts) { "custom: #{key}" }
      expect(described_class.resolve("any.key")).to eq("custom: any.key")
    ensure
      CMDx.message_resolver = nil
    end
  end
end
