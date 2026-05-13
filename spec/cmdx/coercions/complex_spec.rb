# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Complex do
  describe ".call" do
    it "returns a Complex unchanged" do
      c = Complex(1, 2)
      expect(described_class.call(c)).to be(c)
    end

    it "parses numeric strings" do
      expect(described_class.call("1+2i")).to eq(Complex(1, 2))
    end

    it "accepts the imaginary option" do
      expect(described_class.call(3, imaginary: 4)).to eq(Complex(3, 4))
    end

    it "returns a Failure for unparseable input" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Coercions::Failure)
    end
  end
end
