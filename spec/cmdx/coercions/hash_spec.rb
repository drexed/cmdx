# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Hash do
  describe ".call" do
    it "returns an empty hash for nil" do
      expect(described_class.call(nil)).to eq({})
    end

    it "returns a Hash unchanged" do
      h = { a: 1 }
      expect(described_class.call(h)).to be(h)
    end

    it "parses JSON object strings" do
      expect(described_class.call('{"a":1}')).to eq({ "a" => 1 })
    end

    it "returns a Failure for JSON arrays" do
      expect(described_class.call("[1,2]")).to be_a(CMDx::Coercions::Failure)
    end

    it "calls #to_hash when available" do
      obj = Object.new
      def obj.to_hash = { x: 1 }
      expect(described_class.call(obj)).to eq({ x: 1 })
    end

    it "falls back to #to_h" do
      obj = Object.new
      def obj.to_h = { y: 2 }
      expect(described_class.call(obj)).to eq({ y: 2 })
    end

    it "returns a Failure for unknown types" do
      expect(described_class.call(42)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for malformed JSON strings" do
      expect(described_class.call("{bad")).to be_a(CMDx::Coercions::Failure)
    end
  end
end
