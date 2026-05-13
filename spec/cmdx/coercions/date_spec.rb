# frozen_string_literal: true

require "date"

RSpec.describe CMDx::Coercions::Date do
  describe ".call" do
    it "returns a Date unchanged" do
      d = Date.new(2024, 1, 2)
      expect(described_class.call(d)).to be(d)
    end

    it "parses an ISO date string" do
      expect(described_class.call("2024-01-02")).to eq(Date.new(2024, 1, 2))
    end

    it "honors :strptime" do
      expect(described_class.call("02/01/2024", strptime: "%d/%m/%Y")).to eq(Date.new(2024, 1, 2))
    end

    it "calls #to_date when present" do
      expect(described_class.call(Time.new(2024, 1, 2))).to eq(Date.new(2024, 1, 2))
    end

    it "returns a Failure for an unknown value type" do
      expect(described_class.call(42)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for a malformed string" do
      expect(described_class.call("not a date")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure when strptime fails" do
      expect(described_class.call("x", strptime: "%d/%m/%Y")).to be_a(CMDx::Coercions::Failure)
    end
  end
end
