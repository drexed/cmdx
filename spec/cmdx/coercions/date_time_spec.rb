# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::DateTime do
  describe ".call" do
    it "returns a DateTime unchanged" do
      dt = DateTime.new(2024, 5, 1, 8, 30, 0)
      expect(described_class.call(dt)).to eq(dt)
    end

    it "parses a string" do
      result = described_class.call("2024-05-01T10:15:30+00:00")
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(5)
      expect(result.day).to eq(1)
    end

    it "converts Date to DateTime" do
      d = Date.new(2024, 4, 20)
      expect(described_class.call(d)).to eq(d.to_datetime)
    end

    it "converts Time to DateTime" do
      t = Time.utc(2024, 4, 20, 14, 0, 0)
      expect(described_class.call(t)).to eq(t.to_datetime)
    end

    it "raises CMDx::Error on invalid input" do
      expect { described_class.call("bogus") }.to raise_error(CMDx::Error, /date time/)
    end
  end
end
