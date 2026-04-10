# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Integer do
  describe ".call" do
    it "coerces from String" do
      expect(described_class.call("42")).to eq(42)
    end

    it "coerces from Float" do
      expect(described_class.call(9.9)).to eq(9)
    end

    it "raises CMDx::Error for invalid strings" do
      expect { described_class.call("4.2") }.to raise_error(CMDx::Error, /integer/)
    end
  end
end
