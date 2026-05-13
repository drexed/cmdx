# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Array do
  describe ".call" do
    it "returns arrays unchanged" do
      expect(described_class.call([1, 2])).to eq([1, 2])
    end

    it "parses a JSON array string" do
      expect(described_class.call("[1,2,3]")).to eq([1, 2, 3])
    end

    it "wraps a non-array JSON value in an array" do
      expect(described_class.call("42")).to eq(["42"])
    end

    it "wraps unparseable strings in a single-element array" do
      expect(described_class.call("not json")).to eq(["not json"])
    end

    it "calls to_a when available" do
      expect(described_class.call(1..3)).to eq([1, 2, 3])
    end

    it "wraps scalars in an array" do
      expect(described_class.call(42)).to eq([42])
    end

    it "returns a coercion failure when to_a raises TypeError" do
      value = Object.new
      def value.to_a; raise TypeError; end # rubocop:disable Style/SingleLineMethods

      result = described_class.call(value)
      expect(result).to be_a(CMDx::Coercions::Failure)
    end
  end
end
