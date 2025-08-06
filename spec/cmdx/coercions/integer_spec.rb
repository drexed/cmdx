# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Integer do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a valid string" do
      it "coerces string integer to Integer" do
        result = coercion.call("123")

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end

      it "coerces negative string to Integer" do
        result = coercion.call("-456")

        expect(result).to be_a(Integer)
        expect(result).to eq(-456)
      end

      it "coerces zero string to Integer" do
        result = coercion.call("0")

        expect(result).to be_a(Integer)
        expect(result).to eq(0)
      end

      it "coerces string with leading/trailing whitespace to Integer" do
        result = coercion.call("  789  ")

        expect(result).to be_a(Integer)
        expect(result).to eq(789)
      end

      it "coerces string with positive sign to Integer" do
        result = coercion.call("+42")

        expect(result).to be_a(Integer)
        expect(result).to eq(42)
      end

      it "coerces octal string to Integer" do
        result = coercion.call("0777")

        expect(result).to be_a(Integer)
        expect(result).to eq(511)
      end

      it "coerces hexadecimal string to Integer" do
        result = coercion.call("0xFF")

        expect(result).to be_a(Integer)
        expect(result).to eq(255)
      end

      it "coerces binary string to Integer" do
        result = coercion.call("0b1010")

        expect(result).to be_a(Integer)
        expect(result).to eq(10)
      end
    end

    context "when value is a numeric type" do
      it "coerces Integer to Integer" do
        result = coercion.call(123)

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end

      it "coerces negative Integer to Integer" do
        result = coercion.call(-456)

        expect(result).to be_a(Integer)
        expect(result).to eq(-456)
      end

      it "coerces Float to Integer" do
        result = coercion.call(123.0)

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end

      it "coerces negative Float to Integer" do
        result = coercion.call(-456.0)

        expect(result).to be_a(Integer)
        expect(result).to eq(-456)
      end

      it "coerces Rational to Integer" do
        result = coercion.call(Rational(15, 3))

        expect(result).to be_a(Integer)
        expect(result).to eq(5)
      end

      it "coerces BigDecimal to Integer" do
        result = coercion.call(BigDecimal(123))

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end

      it "coerces Complex with zero imaginary part to Integer" do
        result = coercion.call(Complex(123, 0))

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end
    end

    context "when value has fractional part" do
      it "truncates Float with fractional part to Integer" do
        result = coercion.call(123.456)

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end

      it "truncates negative Float with fractional part to Integer" do
        result = coercion.call(-123.456)

        expect(result).to be_a(Integer)
        expect(result).to eq(-123)
      end

      it "raises CoercionError for string decimal" do
        expect { coercion.call("123.789") }.to raise_error(CMDx::CoercionError)
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for invalid string" do
        expect { coercion.call("abc") }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for boolean" do
        expect { coercion.call(true) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ a: 1 }) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for Complex with non-zero imaginary part" do
        expect { coercion.call(Complex(1, 2)) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for Infinity" do
        expect { coercion.call(Float::INFINITY) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for NaN" do
        expect { coercion.call(Float::NAN) }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for string with invalid characters" do
        expect { coercion.call("123abc") }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for string with multiple decimal points" do
        expect { coercion.call("12.34.56") }.to raise_error(CMDx::CoercionError)
      end

      it "raises CoercionError for value that triggers RangeError" do
        # Test using a value that would trigger RangeError in Integer conversion
        very_large_number = ("9" * 1000) + ".0"

        expect { coercion.call(very_large_number) }.to raise_error(CMDx::CoercionError)
      end
    end

    context "with options parameter" do
      it "accepts options parameter but ignores it" do
        result = coercion.call("123", { unused_option: true })

        expect(result).to be_a(Integer)
        expect(result).to eq(123)
      end
    end
  end
end
