# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Float do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a valid string" do
      it "coerces string integer to Float" do
        result = coercion.call("123")

        expect(result).to be_a(Float)
        expect(result).to eq(123.0)
      end

      it "coerces string decimal to Float" do
        result = coercion.call("123.456")

        expect(result).to be_a(Float)
        expect(result).to eq(123.456)
      end

      it "coerces negative string to Float" do
        result = coercion.call("-123.456")

        expect(result).to be_a(Float)
        expect(result).to eq(-123.456)
      end

      it "coerces zero string to Float" do
        result = coercion.call("0")

        expect(result).to be_a(Float)
        expect(result).to eq(0.0)
      end

      it "coerces negative zero string to Float" do
        result = coercion.call("-0")

        expect(result).to be_a(Float)
        expect(result).to eq(-0.0)
      end

      it "coerces string with scientific notation to Float" do
        result = coercion.call("1.23e4")

        expect(result).to be_a(Float)
        expect(result).to eq(1.23e4)
      end

      it "coerces string with negative scientific notation to Float" do
        result = coercion.call("-1.23e-4")

        expect(result).to be_a(Float)
        expect(result).to eq(-1.23e-4)
      end

      it "coerces string with positive exponent notation to Float" do
        result = coercion.call("1.5E+2")

        expect(result).to be_a(Float)
        expect(result).to eq(150.0)
      end

      it "coerces string with leading/trailing whitespace to Float" do
        result = coercion.call("  123.45  ")

        expect(result).to be_a(Float)
        expect(result).to eq(123.45)
      end
    end

    context "when value is a numeric type" do
      it "coerces integer to Float" do
        result = coercion.call(42)

        expect(result).to be_a(Float)
        expect(result).to eq(42.0)
      end

      it "coerces negative integer to Float" do
        result = coercion.call(-42)

        expect(result).to be_a(Float)
        expect(result).to eq(-42.0)
      end

      it "coerces zero integer to Float" do
        result = coercion.call(0)

        expect(result).to be_a(Float)
        expect(result).to eq(0.0)
      end

      it "returns Float unchanged" do
        value = 123.456
        result = coercion.call(value)

        expect(result).to be_a(Float)
        expect(result).to eq(value)
        expect(result).to be(value)
      end

      it "coerces BigDecimal to Float" do
        value = BigDecimal("123.456")
        result = coercion.call(value)

        expect(result).to be_a(Float)
        expect(result).to eq(123.456)
      end

      it "coerces Rational to Float" do
        value = Rational(3, 4)
        result = coercion.call(value)

        expect(result).to be_a(Float)
        expect(result).to eq(0.75)
      end

      it "coerces Complex with zero imaginary part to Float" do
        value = Complex(123.456, 0)
        result = coercion.call(value)

        expect(result).to be_a(Float)
        expect(result).to eq(123.456)
      end
    end

    context "when value is an invalid type" do
      it "raises CoercionError for non-numeric string" do
        expect { coercion.call("not_a_number") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for string with letters mixed with numbers" do
        expect { coercion.call("123abc") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for string with multiple decimal points" do
        expect { coercion.call("123.45.67") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for boolean true" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for boolean false" do
        expect { coercion.call(false) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for Complex with non-zero imaginary part" do
        expect { coercion.call(Complex(1, 2)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for infinity string" do
        expect { coercion.call("Infinity") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for negative infinity string" do
        expect { coercion.call("-Infinity") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end

      it "raises CoercionError for NaN string" do
        expect { coercion.call("NaN") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end
    end

    context "when value is out of range" do
      it "converts extremely large numbers to Infinity" do
        large_number = "1" + ("0" * 400) # rubocop:disable Style/StringConcatenation
        result = coercion.call(large_number)

        expect(result).to be_a(Float)
        expect(result).to be_infinite
        expect(result).to be > 0
      end
    end

    context "with options parameter" do
      it "ignores options and coerces successfully" do
        result = coercion.call("123.45", precision: 2)

        expect(result).to be_a(Float)
        expect(result).to eq(123.45)
      end

      it "ignores options and raises error for invalid input" do
        expect { coercion.call("invalid", precision: 2) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a float")
      end
    end
  end
end
