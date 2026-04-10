# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  describe ".call" do
    it "returns a BigDecimal unchanged" do
      bd = BigDecimal("12.34")
      expect(described_class.call(bd)).to eq(bd)
    end

    it "coerces from String" do
      expect(described_class.call("99.5")).to eq(BigDecimal("99.5"))
    end

    it "coerces from Float" do
      expect(described_class.call(1.25)).to eq(BigDecimal("1.25"))
    end

    it "coerces from Integer" do
      expect(described_class.call(7)).to eq(BigDecimal("7"))
    end
  end
end
