# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a valid string" do
      it "coerces string integer to BigDecimal" do
        result = coercion.call("123")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal(123))
      end

      it "coerces string decimal to BigDecimal" do
        result = coercion.call("123.456")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456"))
      end

      it "coerces negative string to BigDecimal" do
        result = coercion.call("-123.456")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("-123.456"))
      end

      it "coerces string with scientific notation to BigDecimal" do
        result = coercion.call("1.23e4")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("1.23e4"))
      end

      it "coerces zero string to BigDecimal" do
        result = coercion.call("0")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal(0))
      end
    end

    context "when value is a numeric type" do
      it "coerces integer to BigDecimal" do
        result = coercion.call(123)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal(123))
      end

      it "coerces float to BigDecimal" do
        result = coercion.call(123.456)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456"))
      end

      it "coerces rational to BigDecimal" do
        result = coercion.call(Rational(22, 7))

        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to be_within(0.001).of(3.14285)
      end

      it "coerces existing BigDecimal" do
        original = BigDecimal("123.456")
        result = coercion.call(original)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(original)
      end
    end

    context "with precision option" do
      it "uses custom precision when provided" do
        result = coercion.call("123.456789", precision: 4)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456789", 4))
      end

      it "uses default precision when not provided" do
        result = coercion.call("123.456789")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456789", 14))
      end

      it "uses zero precision" do
        result = coercion.call("123.456", precision: 0)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456", 0))
      end
    end

    context "with invalid values" do
      it "raises CoercionError for non-numeric string" do
        expect { coercion.call("invalid") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for boolean" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for complex number" do
        expect { coercion.call(Complex(1, 2)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end
    end

    context "with edge cases" do
      it "coerces string with leading/trailing whitespace" do
        result = coercion.call("  123.456  ")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456"))
      end

      it "coerces string with plus sign" do
        result = coercion.call("+123.456")

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("123.456"))
      end

      it "raises CoercionError for string with invalid characters" do
        expect { coercion.call("123.45.67") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end

      it "raises CoercionError for string with letters mixed in" do
        expect { coercion.call("12a3.456") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end
    end
  end
end
