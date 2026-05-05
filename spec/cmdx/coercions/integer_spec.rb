# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Integer do
  describe ".call" do
    it "converts numeric strings" do
      expect(described_class.call("42")).to eq(42)
    end

    it "converts floats" do
      expect(described_class.call(3.9)).to eq(3)
    end

    it "returns a Failure for unparseable input" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for Float::INFINITY" do
      expect(described_class.call(Float::INFINITY)).to be_a(CMDx::Coercions::Failure)
    end
  end
end
