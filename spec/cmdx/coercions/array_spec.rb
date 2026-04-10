# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array do
  describe ".call" do
    it "returns an Array unchanged" do
      arr = [1, 2]
      expect(described_class.call(arr)).to equal(arr)
    end

    it "converts a Hash to an Array of pairs" do
      expect(described_class.call({ a: 1, b: 2 })).to eq([[:a, 1], [:b, 2]])
    end

    it "returns an empty Array for nil" do
      expect(described_class.call(nil)).to eq([])
    end

    it "wraps other values per Kernel.Array" do
      expect(described_class.call(1)).to eq([1])
    end

    it "raises CMDx::Error when coercion fails" do
      bad = Object.new
      def bad.to_ary
        raise StandardError, "nope"
      end

      expect { described_class.call(bad) }.to raise_error(CMDx::Error, /array/)
    end
  end
end
