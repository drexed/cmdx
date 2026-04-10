# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Time do
  describe ".call" do
    it "returns Time unchanged" do
      t = Time.utc(2024, 2, 1, 0, 0, 0)
      expect(described_class.call(t)).to eq(t)
    end

    it "parses a string" do
      result = described_class.call("2024-02-01T00:00:00Z")
      expect(result).to be_a(Time)
      expect(result.utc.year).to eq(2024)
      expect(result.utc.month).to eq(2)
      expect(result.utc.day).to eq(1)
    end

    it "converts Date to Time" do
      d = Date.new(2024, 2, 1)
      expect(described_class.call(d)).to eq(d.to_time)
    end

    it "converts Integer epoch seconds via Time.at" do
      expect(described_class.call(0)).to eq(Time.at(0))
    end

    it "raises CMDx::Error on invalid input" do
      expect { described_class.call("not-a-time") }.to raise_error(CMDx::Error, /time/)
    end
  end
end
