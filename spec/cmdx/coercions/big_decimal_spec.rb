# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      result = described_class.call("123.45")

      expect(result).to be_a(BigDecimal)
      expect(result.to_s).to eq("0.12345e3")
    end
  end

  describe "#call" do
    context "with string values" do
      it "converts valid decimal strings" do
        result = coercion.call("123.45")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.12345e3")
      end

      it "converts integer strings" do
        result = coercion.call("100")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.1e3")
      end

      it "converts negative decimal strings" do
        result = coercion.call("-99.99")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("-0.9999e2")
      end

      it "converts zero strings" do
        result = coercion.call("0")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.0")
      end

      it "converts scientific notation strings" do
        result = coercion.call("1.23e2")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.123e3")
      end

      it "raises CoercionError for invalid strings" do
        expect { coercion.call("invalid") }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for strings with mixed content" do
        expect { coercion.call("123.45abc") }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with numeric values" do
      it "converts integers" do
        result = coercion.call(42)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.42e2")
      end

      it "converts floats" do
        result = coercion.call(3.14159)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.314159e1")
      end

      it "converts negative numbers" do
        result = coercion.call(-123)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("-0.123e3")
      end

      it "converts zero" do
        result = coercion.call(0)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.0")
      end

      it "converts very large numbers" do
        result = coercion.call(999_999_999_999)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.999999999999e12")
      end
    end

    context "with BigDecimal values" do
      it "returns BigDecimal values unchanged" do
        input = BigDecimal("123.456")
        result = coercion.call(input)

        expect(result).to be_a(BigDecimal)
        expect(result).to eq(input)
      end
    end

    context "with Rational values" do
      it "converts rational numbers" do
        input = Rational(22, 7)
        result = coercion.call(input)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.31428571428571e1")
      end
    end

    context "with invalid values" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for arrays" do
        expect { coercion.call([1, 2, 3]) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for hashes" do
        expect { coercion.call({ value: 123 }) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
        expect { coercion.call(false) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with precision options" do
      it "uses default precision when no option provided" do
        result = coercion.call("123.456789012345678")

        expect(result).to be_a(BigDecimal)
        # Default precision is 14
        expect(result.to_s).to eq("0.123456789012345678e3")
      end

      it "uses custom precision when provided" do
        result = coercion.call("123.456789", precision: 6)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.123456789e3")
      end

      it "uses higher precision when specified" do
        result = coercion.call("123.456789012345678", precision: 20)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.123456789012345678e3")
      end

      it "uses zero precision" do
        result = coercion.call("123.456", precision: 0)

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.123456e3")
      end

      it "ignores non-precision options" do
        result = coercion.call("123.45", other_option: "ignored")

        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to eq("0.12345e3")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "CalculateAmountTask") do
        required :amount, type: :big_decimal
        optional :tax_rate, type: :big_decimal, default: BigDecimal("0.08")

        def call
          context.total_amount = amount * (BigDecimal(1) + tax_rate)
          context.tax_amount = amount * tax_rate
        end
      end
    end

    it "coerces string parameters to BigDecimal" do
      result = task_class.call(amount: "100.50")

      expect(result).to be_success
      expect(result.context.total_amount).to eq(BigDecimal("108.54"))
      expect(result.context.tax_amount).to eq(BigDecimal("8.04"))
    end

    it "coerces numeric parameters to BigDecimal" do
      result = task_class.call(amount: 250)

      expect(result).to be_success
      expect(result.context.total_amount).to eq(BigDecimal(270))
      expect(result.context.tax_amount).to eq(BigDecimal(20))
    end

    it "handles BigDecimal parameters unchanged" do
      amount = BigDecimal("99.99")
      result = task_class.call(amount: amount)

      expect(result).to be_success
      expect(result.context.total_amount).to eq(BigDecimal("107.9892"))
    end

    it "uses default values for optional BigDecimal parameters" do
      result = task_class.call(amount: "50.00")

      expect(result).to be_success
      expect(result.context.tax_amount).to eq(BigDecimal("4.00"))
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(amount: "100.00", tax_rate: "0.10")

      expect(result).to be_success
      expect(result.context.total_amount).to eq(BigDecimal("110.00"))
      expect(result.context.tax_amount).to eq(BigDecimal("10.00"))
    end

    it "fails when coercion fails for invalid values" do
      result = task_class.call(amount: "invalid_amount")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a big decimal")
    end

    it "preserves precision in calculations" do
      result = task_class.call(amount: "33.333333", tax_rate: "0.075")

      expect(result).to be_success
      # BigDecimal preserves precision unlike Float
      expect(result.context.total_amount.to_s).to eq("0.35833332975e2")
    end
  end
end
