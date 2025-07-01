# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  describe "#call" do
    context "with string values" do
      it "converts numeric string to BigDecimal" do
        result = described_class.call("123.45")
        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to eq(123.45)
      end

      it "converts integer string to BigDecimal" do
        result = described_class.call("123")
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(123)
      end

      it "converts negative string to BigDecimal" do
        result = described_class.call("-456.78")
        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to eq(-456.78)
      end

      it "converts zero string to BigDecimal" do
        result = described_class.call("0")
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(0)
      end

      it "converts scientific notation to BigDecimal" do
        result = described_class.call("1.23e2")
        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to eq(123.0)
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with numeric values" do
      it "converts integer to BigDecimal" do
        result = described_class.call(123)
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(123)
      end

      it "converts negative integer to BigDecimal" do
        result = described_class.call(-456)
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(-456)
      end

      it "converts float to BigDecimal" do
        result = described_class.call(3.14)
        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to be_within(0.01).of(3.14)
      end

      it "converts zero to BigDecimal" do
        result = described_class.call(0)
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(0)
      end
    end

    context "with BigDecimal values" do
      it "returns BigDecimal unchanged" do
        big_decimal = BigDecimal("123.45")
        expect(described_class.call(big_decimal)).to eq(big_decimal)
      end
    end

    context "with precision options" do
      it "uses custom precision" do
        result = described_class.call("0.333333", precision: 6)
        expect(result).to be_a(BigDecimal)
        expect(result.to_s).to include("0.333333")
      end

      it "uses default precision when not specified" do
        result = described_class.call("0.333333")
        expect(result).to be_a(BigDecimal)
      end

      it "handles zero precision" do
        result = described_class.call("123", precision: 0)
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(123)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([1, 2, 3])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ key: "value" })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a big decimal/)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "big decimal", default: "could not coerce into a big decimal").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles very large numbers" do
        large_number = "999999999999999999999999999999.123456789"
        result = described_class.call(large_number)
        expect(result).to be_a(BigDecimal)
      end

      it "handles very small numbers" do
        small_number = "0.000000000000000001"
        result = described_class.call(small_number)
        expect(result).to be_a(BigDecimal)
      end

      it "handles high precision calculations" do
        result = described_class.call("1.23456789012345678901234567890", precision: 30)
        expect(result).to be_a(BigDecimal)
      end

      it "handles negative zero" do
        result = described_class.call("-0")
        expect(result).to be_a(BigDecimal)
        expect(result.to_i).to eq(0)
      end
    end
  end
end
