# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a valid string" do
      it "coerces string integer to Rational" do
        result = coercion.call("123")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(123))
      end

      it "coerces string fraction to Rational" do
        result = coercion.call("3/4")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "coerces string decimal to Rational" do
        result = coercion.call("0.5")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(1, 2))
      end

      it "coerces negative string to Rational" do
        result = coercion.call("-456")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-456))
      end

      it "coerces negative fraction string to Rational" do
        result = coercion.call("-3/4")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-3, 4))
      end

      it "coerces zero string to Rational" do
        result = coercion.call("0")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(0))
      end

      it "coerces string with positive sign to Rational" do
        result = coercion.call("+42")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(42))
      end

      it "coerces string with leading/trailing whitespace to Rational" do
        result = coercion.call("  3/5  ")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 5))
      end

      it "coerces improper fraction string to Rational" do
        result = coercion.call("7/3")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(7, 3))
      end

      it "coerces decimal with many digits to Rational" do
        result = coercion.call("0.125")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(1, 8))
      end

      it "coerces scientific notation string to Rational" do
        result = coercion.call("1e3")

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(1000))
      end
    end

    context "when value is a valid number" do
      it "coerces integer to Rational" do
        result = coercion.call(42)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(42))
      end

      it "coerces negative integer to Rational" do
        result = coercion.call(-42)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-42))
      end

      it "coerces zero to Rational" do
        result = coercion.call(0)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(0))
      end

      it "coerces float to Rational" do
        result = coercion.call(0.75)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "coerces negative float to Rational" do
        result = coercion.call(-0.25)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-1, 4))
      end

      it "coerces BigDecimal to Rational" do
        result = coercion.call(BigDecimal("0.333"))

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(333, 1000))
      end

      it "coerces existing Rational to Rational" do
        input = Rational(5, 8)
        result = coercion.call(input)

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(5, 8))
        expect(result).to be(input)
      end

      it "coerces Complex with zero imaginary part to Rational" do
        result = coercion.call(Complex(3, 0))

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3))
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for non-numeric string" do
        expect { coercion.call("not_a_number") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for string with letters mixed with numbers" do
        expect { coercion.call("123abc") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for string with invalid fraction" do
        expect { coercion.call("3//4") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for boolean true" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for boolean false" do
        expect { coercion.call(false) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for Complex with non-zero imaginary part" do
        expect { coercion.call(Complex(1, 2)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for Infinity" do
        expect { coercion.call(Float::INFINITY) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for NaN" do
        expect { coercion.call(Float::NAN) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for division by zero string" do
        expect { coercion.call("1/0") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for string with multiple decimal points" do
        expect { coercion.call("1.2.3") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for string with multiple slashes" do
        expect { coercion.call("1/2/3") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end

      it "raises CoercionError for string with text after number" do
        expect { coercion.call("42units") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a rational")
      end
    end

    context "with options parameter" do
      it "accepts options parameter but ignores it" do
        result = coercion.call("3/4", { unused_option: true })

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "accepts empty options hash" do
        result = coercion.call("1/2", {})

        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(1, 2))
      end
    end
  end
end
