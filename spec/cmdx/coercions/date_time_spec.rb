# frozen_string_literal: true

require "date"

RSpec.describe CMDx::Coercions::DateTime do
  describe ".call" do
    it "returns a DateTime unchanged" do
      dt = DateTime.new(2024, 1, 2, 3, 4, 5)
      expect(described_class.call(dt)).to be(dt)
    end

    it "parses an ISO-8601 string" do
      expect(described_class.call("2024-01-02T03:04:05Z"))
        .to eq(DateTime.new(2024, 1, 2, 3, 4, 5))
    end

    it "honors :strptime" do
      expect(described_class.call("02-01-2024", strptime: "%d-%m-%Y"))
        .to eq(DateTime.new(2024, 1, 2))
    end

    it "calls #to_datetime when present" do
      expect(described_class.call(Date.new(2024, 1, 2))).to eq(DateTime.new(2024, 1, 2))
    end

    it "returns a Failure for unknown types" do
      expect(described_class.call(42)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for malformed strings" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end
  end
end
