# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Symbol do
  describe ".call" do
    it "returns a Symbol unchanged" do
      expect(described_class.call(:a)).to eq(:a)
    end

    it "converts strings to symbols" do
      expect(described_class.call("hello")).to eq(:hello)
    end

    it "converts numbers to symbols" do
      expect(described_class.call(42)).to eq(:"42")
    end

    it "returns a Failure for objects without a to_s" do
      obj = BasicObject.new
      expect(described_class.call(obj)).to be_a(CMDx::Coercions::Failure)
    end
  end
end
