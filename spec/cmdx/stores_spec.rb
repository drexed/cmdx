# frozen_string_literal: true

RSpec.describe CMDx::Stores do
  describe ".get" do
    it "delegates to the configured store" do
      memory = CMDx::Stores::Memory.new
      CMDx.configuration.store = memory
      memory.set(:k, "v")

      expect(described_class.get(:k)).to eq("v")
    end
  end

  describe "default configuration" do
    it "uses an in-memory store" do
      expect(CMDx.configuration.store).to be_a(CMDx::Stores::Memory)
    end
  end
end
