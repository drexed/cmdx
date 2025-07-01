# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  describe "#call" do
    context "with complex values" do
      it "returns Complex unchanged" do
        complex = Complex(3, 4)
        expect(described_class.call(complex)).to eq(complex)
      end

      it "returns negative Complex unchanged" do
        complex = Complex(-3, -4)
        expect(described_class.call(complex)).to eq(complex)
      end

      it "returns Complex with zero imaginary part unchanged" do
        complex = Complex(5, 0)
        expect(described_class.call(complex)).to eq(complex)
      end
    end

    context "with string values" do
      it "converts complex string to Complex" do
        result = described_class.call("3+4i")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3, 4))
      end

      it "converts negative complex string to Complex" do
        result = described_class.call("-3-4i")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(-3, -4))
      end

      it "raises CoercionError for complex string with spaces" do
        expect do
          described_class.call("3 + 4i")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "converts pure imaginary string to Complex" do
        result = described_class.call("4i")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, 4))
      end

      it "converts real number string to Complex" do
        result = described_class.call("5")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(5, 0))
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with numeric values" do
      it "converts integer to Complex" do
        result = described_class.call(5)
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(5, 0))
      end

      it "converts negative integer to Complex" do
        result = described_class.call(-5)
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(-5, 0))
      end

      it "converts zero to Complex" do
        result = described_class.call(0)
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, 0))
      end

      it "converts float to Complex" do
        result = described_class.call(3.14)
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3.14, 0))
      end

      it "converts negative float to Complex" do
        result = described_class.call(-2.5)
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(-2.5, 0))
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([3, 4])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ real: 3, imaginary: 4 })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = described_class.call("3+4i", { key: "value" })
        expect(result).to eq(Complex(3, 4))
      end

      it "works with empty options" do
        result = described_class.call(5, {})
        expect(result).to eq(Complex(5, 0))
      end

      it "works with nil options" do
        result = described_class.call("2i", nil)
        expect(result).to eq(Complex(0, 2))
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "complex", default: "could not coerce into a complex").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles complex with decimal parts" do
        result = described_class.call("3.14+2.71i")
        expect(result).to be_a(Complex)
        expect(result.real).to be_within(0.01).of(3.14)
        expect(result.imaginary).to be_within(0.01).of(2.71)
      end

      it "handles complex with negative imaginary part" do
        result = described_class.call("5-3i")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(5, -3))
      end

      it "handles pure negative imaginary" do
        result = described_class.call("-7i")
        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, -7))
      end

      it "handles scientific notation in complex" do
        result = described_class.call("1e2+3e-1i")
        expect(result).to be_a(Complex)
        expect(result.real).to be_within(0.01).of(100.0)
        expect(result.imaginary).to be_within(0.01).of(0.3)
      end

      it "handles very large complex numbers" do
        result = described_class.call("999999999999+888888888888i")
        expect(result).to be_a(Complex)
        expect(result.real).to eq(999_999_999_999)
        expect(result.imaginary).to eq(888_888_888_888)
      end
    end
  end
end
