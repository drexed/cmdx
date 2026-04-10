# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  describe ".call" do
    it "returns a Rational unchanged" do
      r = Rational(2, 3)
      expect(described_class.call(r)).to eq(r)
    end

    it "coerces from String" do
      expect(described_class.call("3/4")).to eq(Rational(3, 4))
    end

    it "coerces from a number" do
      expect(described_class.call(0.5)).to eq(Rational(1, 2))
    end

    it "raises CMDx::Error on invalid input" do
      expect { described_class.call("not-rational") }.to raise_error(CMDx::Error, /rational/)
    end
  end
end
