# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Float do
  describe ".call" do
    it "coerces from String" do
      expect(described_class.call("3.5")).to eq(3.5)
    end

    it "coerces from Integer" do
      expect(described_class.call(10)).to eq(10.0)
    end

    it "raises CMDx::Error for invalid strings" do
      expect { described_class.call("x.y") }.to raise_error(CMDx::Error, /float/)
    end
  end
end
