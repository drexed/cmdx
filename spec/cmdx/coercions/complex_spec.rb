# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  describe ".call" do
    it "returns a Complex unchanged" do
      c = Complex(3, 4)
      expect(described_class.call(c)).to eq(c)
    end

    it "coerces from a numeric value" do
      expect(described_class.call(5)).to eq(Complex(5, 0))
    end

    it "coerces from a string" do
      expect(described_class.call("2+3i")).to eq(Complex(2, 3))
    end

    it "raises CMDx::Error on invalid input" do
      expect { described_class.call("not-a-complex") }.to raise_error(CMDx::Error, /complex/)
    end
  end
end
