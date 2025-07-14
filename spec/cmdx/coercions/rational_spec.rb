# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("1/2")).to eq(Rational(1, 2))
    end
  end

  describe "#call" do
    context "with string values" do
      it "converts fraction strings to rationals" do
        result = coercion.call("1/2")

        expect(result).to eq(Rational(1, 2))
      end

      it "converts decimal strings to rationals" do
        result = coercion.call("0.25")

        expect(result).to eq(Rational(1, 4))
      end

      it "converts integer strings to rationals" do
        result = coercion.call("5")

        expect(result).to eq(Rational(5, 1))
      end

      it "converts negative fraction strings to rationals" do
        result = coercion.call("-3/4")

        expect(result).to eq(Rational(-3, 4))
      end

      it "converts zero strings to rationals" do
        result = coercion.call("0")

        expect(result).to eq(Rational(0, 1))
      end

      it "raises CoercionError for invalid string formats" do
        expect { coercion.call("invalid") }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for malformed fractions" do
        expect { coercion.call("1/0/2") }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with numeric values" do
      it "converts integers to rationals" do
        result = coercion.call(42)

        expect(result).to eq(Rational(42, 1))
      end

      it "converts floats to rationals" do
        result = coercion.call(0.5)

        expect(result).to eq(Rational(1, 2))
      end

      it "converts negative integers to rationals" do
        result = coercion.call(-10)

        expect(result).to eq(Rational(-10, 1))
      end

      it "converts zero to rationals" do
        result = coercion.call(0)

        expect(result).to eq(Rational(0, 1))
      end

      it "converts BigDecimal to rationals" do
        result = coercion.call(BigDecimal("3.14"))

        expect(result).to eq(Rational(BigDecimal("3.14")))
      end

      it "raises CoercionError for NaN float" do
        expect { coercion.call(Float::NAN) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for infinite float" do
        expect { coercion.call(Float::INFINITY) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with rational values" do
      it "returns rational values unchanged" do
        input = Rational(3, 4)
        result = coercion.call(input)

        expect(result).to eq(Rational(3, 4))
      end

      it "returns negative rational values unchanged" do
        input = Rational(-2, 5)
        result = coercion.call(input)

        expect(result).to eq(Rational(-2, 5))
      end

      it "returns zero rational unchanged" do
        input = Rational(0, 1)
        result = coercion.call(input)

        expect(result).to eq(Rational(0, 1))
      end
    end

    context "with complex numbers" do
      it "converts complex numbers with zero imaginary part to rationals" do
        result = coercion.call(Complex(3, 0))

        expect(result).to eq(Rational(3, 1))
      end

      it "raises CoercionError for complex numbers with non-zero imaginary part" do
        expect { coercion.call(Complex(1, 2)) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect { coercion.call(true) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for false" do
        expect { coercion.call(false) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with array values" do
      it "raises CoercionError for arrays" do
        expect { coercion.call([1, 2]) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for empty arrays" do
        expect { coercion.call([]) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for hashes" do
        expect { coercion.call({ a: 1 }) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for empty hashes" do
        expect { coercion.call({}) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with complex objects" do
      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for symbols" do
        expect { coercion.call(:symbol) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call("1/3", { some: "option" })

        expect(result).to eq(Rational(1, 3))
      end

      it "processes valid values with options parameter" do
        result = coercion.call(0.75, { some: "option" })

        expect(result).to eq(Rational(3, 4))
      end

      it "raises CoercionError for invalid values even with options" do
        expect { coercion.call("invalid", { some: "option" }) }.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "CalculateRatioTask") do
        required :ratio, type: :rational
        optional :multiplier, type: :rational, default: Rational(1, 1)

        def call
          context.calculated_ratio = ratio * multiplier
          context.decimal_value = ratio.to_f
        end
      end
    end

    it "coerces string fraction parameters to rationals" do
      result = task_class.call(ratio: "3/4")

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(3, 4))
      expect(result.context.decimal_value).to eq(0.75)
    end

    it "coerces decimal string parameters to rationals" do
      result = task_class.call(ratio: "0.5")

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(1, 2))
      expect(result.context.decimal_value).to eq(0.5)
    end

    it "coerces integer parameters to rationals" do
      result = task_class.call(ratio: 2)

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(2, 1))
      expect(result.context.decimal_value).to eq(2.0)
    end

    it "coerces float parameters to rationals" do
      result = task_class.call(ratio: 0.25)

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(1, 4))
      expect(result.context.decimal_value).to eq(0.25)
    end

    it "handles rational parameters unchanged" do
      result = task_class.call(ratio: Rational(2, 3))

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(2, 3))
      expect(result.context.decimal_value).to be_within(0.001).of(0.667)
    end

    it "uses default values for optional rational parameters" do
      result = task_class.call(ratio: "1/2")

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(1, 2))
    end

    it "performs calculations with both parameters" do
      result = task_class.call(ratio: "1/3", multiplier: "2/1")

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(2, 3))
      expect(result.context.decimal_value).to be_within(0.001).of(0.333)
    end

    it "handles negative rationals" do
      result = task_class.call(ratio: "-1/4")

      expect(result).to be_success
      expect(result.context.calculated_ratio).to eq(Rational(-1, 4))
      expect(result.context.decimal_value).to eq(-0.25)
    end
  end
end
