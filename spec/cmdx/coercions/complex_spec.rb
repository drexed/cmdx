# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call(5)).to eq(Complex(5))
    end
  end

  describe "#call" do
    context "with numeric values" do
      it "converts integers to complex numbers" do
        result = coercion.call(5)

        expect(result).to eq(Complex(5, 0))
      end

      it "converts floats to complex numbers" do
        result = coercion.call(3.14)

        expect(result).to eq(Complex(3.14, 0))
      end

      it "converts zero to complex number" do
        result = coercion.call(0)

        expect(result).to eq(Complex(0, 0))
      end

      it "converts negative numbers to complex numbers" do
        result = coercion.call(-2.5)

        expect(result).to eq(Complex(-2.5, 0))
      end

      it "converts BigDecimal to complex numbers" do
        result = coercion.call(BigDecimal("3.14"))

        expect(result).to eq(Complex(BigDecimal("3.14"), 0))
      end

      it "converts Rational to complex numbers" do
        result = coercion.call(Rational(3, 4))

        expect(result).to eq(Complex(Rational(3, 4), 0))
      end
    end

    context "with string representations" do
      it "converts basic complex string representations" do
        result = coercion.call("2+3i")

        expect(result).to eq(Complex(2, 3))
      end

      it "converts complex strings with negative imaginary parts" do
        result = coercion.call("1-2i")

        expect(result).to eq(Complex(1, -2))
      end

      it "converts pure imaginary strings" do
        result = coercion.call("5i")

        expect(result).to eq(Complex(0, 5))
      end

      it "converts negative pure imaginary strings" do
        result = coercion.call("-3i")

        expect(result).to eq(Complex(0, -3))
      end

      it "converts pure real strings" do
        result = coercion.call("7")

        expect(result).to eq(Complex(7, 0))
      end

      it "converts complex strings with decimal parts" do
        result = coercion.call("1.5+2.5i")

        expect(result).to eq(Complex(1.5, 2.5))
      end
    end

    context "with complex number values" do
      it "returns complex numbers unchanged" do
        input = Complex(2, 3)
        result = coercion.call(input)

        expect(result).to eq(Complex(2, 3))
      end

      it "returns zero complex numbers unchanged" do
        input = Complex(0, 0)
        result = coercion.call(input)

        expect(result).to eq(Complex(0, 0))
      end
    end

    context "with invalid values" do
      it "raises CoercionError for invalid string formats" do
        expect { coercion.call("invalid") }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for nil values" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for arrays" do
        expect { coercion.call([1, 2, 3]) }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for hashes" do
        expect { coercion.call({ a: 1 }) }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end

      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(CMDx::CoercionError, /could not coerce into a complex/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter for valid values" do
        result = coercion.call("2+3i", { some: "option" })

        expect(result).to eq(Complex(2, 3))
      end

      it "still raises errors for invalid values with options" do
        expect { coercion.call("invalid", { some: "option" }) }.to raise_error(CMDx::CoercionError)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessComplexTask") do
        required :value, type: :complex
        optional :coefficient, type: :complex, default: Complex(1, 0)

        def call
          context.result = value * coefficient
          context.magnitude = value.abs
        end
      end
    end

    it "coerces string parameters to complex numbers" do
      result = task_class.call(value: "2+3i")

      expect(result).to be_success
      expect(result.context.result).to eq(Complex(2, 3))
      expect(result.context.magnitude).to be_within(0.001).of(3.606)
    end

    it "coerces numeric parameters to complex numbers" do
      result = task_class.call(value: 5)

      expect(result).to be_success
      expect(result.context.result).to eq(Complex(5, 0))
      expect(result.context.magnitude).to eq(5.0)
    end

    it "handles complex parameters unchanged" do
      result = task_class.call(value: Complex(1, -2))

      expect(result).to be_success
      expect(result.context.result).to eq(Complex(1, -2))
      expect(result.context.magnitude).to be_within(0.001).of(2.236)
    end

    it "uses default values for optional complex parameters" do
      result = task_class.call(value: Complex(2, 3))

      expect(result).to be_success
      expect(result.context.result).to eq(Complex(2, 3))
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(value: "1+2i", coefficient: "2-i")

      expect(result).to be_success
      expect(result.context.result).to eq(Complex(4, 3))
    end

    it "fails when coercion fails for invalid values" do
      result = task_class.call(value: "invalid")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a complex")
    end
  end
end
