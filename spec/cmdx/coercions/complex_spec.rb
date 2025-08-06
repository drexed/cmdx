# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a valid string" do
      it "coerces string integer to Complex" do
        result = coercion.call("123")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(123))
      end

      it "coerces string decimal to Complex" do
        result = coercion.call("123.456")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(123.456))
      end

      it "coerces negative string to Complex" do
        result = coercion.call("-123.456")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(-123.456))
      end

      it "coerces string with imaginary unit to Complex" do
        result = coercion.call("3+4i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3, 4))
      end

      it "coerces string with negative imaginary unit to Complex" do
        result = coercion.call("3-4i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3, -4))
      end

      it "coerces pure imaginary string to Complex" do
        result = coercion.call("4i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, 4))
      end

      it "coerces zero string to Complex" do
        result = coercion.call("0")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0))
      end

      it "coerces string with scientific notation to Complex" do
        result = coercion.call("1.23e4")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(1.23e4))
      end
    end

    context "when value is a numeric type" do
      it "coerces integer to Complex" do
        result = coercion.call(123)

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(123))
      end

      it "coerces float to Complex" do
        result = coercion.call(123.456)

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(123.456))
      end

      it "coerces rational to Complex" do
        result = coercion.call(Rational(22, 7))

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(Rational(22, 7)))
      end

      it "coerces existing Complex" do
        original = Complex(3, 4)
        result = coercion.call(original)

        expect(result).to be_a(Complex)
        expect(result).to eq(original)
      end

      it "coerces zero to Complex" do
        result = coercion.call(0)

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0))
      end

      it "coerces negative number to Complex" do
        result = coercion.call(-42)

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(-42))
      end
    end

    context "with invalid values" do
      it "raises CoercionError for non-numeric string" do
        expect { coercion.call("invalid") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for boolean" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for Object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end
    end

    context "with edge cases" do
      it "coerces string with decimal imaginary unit" do
        result = coercion.call("1.5+2.7i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(1.5, 2.7))
      end

      it "coerces string with just 'i' as imaginary unit" do
        result = coercion.call("i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, 1))
      end

      it "coerces string with negative imaginary unit 'i'" do
        result = coercion.call("-i")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(0, -1))
      end

      it "coerces string with 'j' notation" do
        result = coercion.call("3+4j")

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3, 4))
      end

      it "raises CoercionError for string with spaces" do
        expect { coercion.call("3 + 4i") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for string with multiple operators" do
        expect { coercion.call("3++4i") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end

      it "raises CoercionError for malformed complex string" do
        expect { coercion.call("3+i4") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end
    end

    context "with options parameter" do
      it "ignores options parameter for valid complex number" do
        result = coercion.call("3+4i", { some: "option" })

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(3, 4))
      end

      it "ignores options parameter for valid numeric value" do
        result = coercion.call(42, { some: "option" })

        expect(result).to be_a(Complex)
        expect(result).to eq(Complex(42))
      end

      it "ignores options parameter for invalid value" do
        expect { coercion.call("invalid", { some: "option" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end
    end
  end
end
