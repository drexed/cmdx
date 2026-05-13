# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Integer do
  describe ".call" do
    it "converts numeric strings" do
      expect(described_class.call("42")).to eq(42)
    end

    it "converts floats" do
      expect(described_class.call(3.9)).to eq(3)
    end

    it "returns a Failure for unparseable input" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for Float::INFINITY" do
      expect(described_class.call(Float::INFINITY)).to be_a(CMDx::Coercions::Failure)
    end

    context "with :base option" do
      it "parses hex strings" do
        expect(described_class.call("0x10", base: 16)).to eq(16)
        expect(described_class.call("ff", base: 16)).to eq(255)
      end

      it "parses binary strings" do
        expect(described_class.call("1010", base: 2)).to eq(10)
      end

      it "ignores :base when the value is not a String" do
        expect(described_class.call(5, base: 16)).to eq(5)
      end

      it "returns a Failure for an invalid string in the given base" do
        expect(described_class.call("nope", base: 16)).to be_a(CMDx::Coercions::Failure)
      end
    end
  end
end
