# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  describe ".call" do
    it "returns a Rational unchanged" do
      r = Rational(1, 2)
      expect(described_class.call(r)).to be(r)
    end

    it "parses numeric strings" do
      expect(described_class.call("1/3")).to eq(Rational(1, 3))
    end

    it "accepts :denominator" do
      expect(described_class.call(3, denominator: 4)).to eq(Rational(3, 4))
    end

    it "returns a Failure for unparseable input" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for zero division" do
      expect(described_class.call(1, denominator: 0)).to be_a(CMDx::Coercions::Failure)
    end
  end
end
