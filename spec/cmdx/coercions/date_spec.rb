# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Date do
  describe ".call" do
    it "returns a Date unchanged" do
      d = Date.new(2024, 6, 1)
      expect(described_class.call(d)).to eq(d)
    end

    it "parses a string" do
      expect(described_class.call("2024-06-15")).to eq(Date.new(2024, 6, 15))
    end

    it "converts Time to Date" do
      t = Time.utc(2024, 3, 10, 12, 0, 0)
      expect(described_class.call(t)).to eq(Date.new(2024, 3, 10))
    end

    it "converts Integer epoch seconds via Time.at" do
      expect(described_class.call(0)).to eq(Time.at(0).to_date)
    end

    it "raises CMDx::Error on invalid input" do
      expect { described_class.call("not-a-date") }.to raise_error(CMDx::Error, /date/)
    end
  end
end
