# frozen_string_literal: true

require "bigdecimal"

RSpec.describe CMDx::Coercions::BigDecimal do
  describe ".call" do
    it "returns a BigDecimal unchanged" do
      bd = BigDecimal("1.5")
      expect(described_class.call(bd)).to eq(bd)
    end

    it "parses numeric strings" do
      expect(described_class.call("3.14")).to eq(BigDecimal("3.14"))
    end

    it "accepts the precision option" do
      expect(described_class.call("1.25", precision: 4)).to be_a(BigDecimal)
    end

    it "returns a Failure for invalid input" do
      expect(described_class.call("not a number")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Coercions::Failure)
    end
  end
end
