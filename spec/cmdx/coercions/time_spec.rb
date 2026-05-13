# frozen_string_literal: true

require "date"

RSpec.describe CMDx::Coercions::Time do
  describe ".call" do
    it "returns a Time unchanged" do
      t = Time.new(2024, 1, 2, 3, 4, 5)
      expect(described_class.call(t)).to be(t)
    end

    it "parses a string" do
      expect(described_class.call("2024-01-02 03:04:05"))
        .to eq(Time.new(2024, 1, 2, 3, 4, 5))
    end

    it "honors :strptime" do
      expect(described_class.call("02-01-2024", strptime: "%d-%m-%Y"))
        .to eq(Time.new(2024, 1, 2))
    end

    it "converts numerics via Time.at" do
      expect(described_class.call(0)).to eq(Time.at(0))
    end

    it "calls #to_time when available" do
      expect(described_class.call(DateTime.new(2024, 1, 2))).to be_a(Time)
    end

    it "returns a Failure for unknown types" do
      expect(described_class.call(Object.new)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for malformed strings" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end
  end
end
