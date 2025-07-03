# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Float do
  describe "#call" do
    context "with float values" do
      it "returns float unchanged" do
        expect(described_class.call(3.14)).to eq(3.14)
      end

      it "returns negative float unchanged" do
        expect(described_class.call(-2.5)).to eq(-2.5)
      end

      it "returns zero float unchanged" do
        expect(described_class.call(0.0)).to eq(0.0)
      end
    end

    context "with integer values" do
      it "converts integer to float" do
        expect(described_class.call(123)).to eq(123.0)
      end

      it "converts negative integer to float" do
        expect(described_class.call(-456)).to eq(-456.0)
      end

      it "converts zero to float" do
        expect(described_class.call(0)).to eq(0.0)
      end
    end

    context "with string values" do
      it "converts numeric string to float" do
        expect(described_class.call("3.14")).to eq(3.14)
      end

      it "converts integer string to float" do
        expect(described_class.call("123")).to eq(123.0)
      end

      it "converts negative string to float" do
        expect(described_class.call("-2.5")).to eq(-2.5)
      end

      it "converts zero string to float" do
        expect(described_class.call("0")).to eq(0.0)
      end

      it "converts scientific notation to float" do
        expect(described_class.call("1e2")).to eq(100.0)
      end

      it "converts negative scientific notation to float" do
        expect(described_class.call("-1e-2")).to eq(-0.01)
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for mixed alphanumeric string" do
        expect do
          described_class.call("123abc")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([1, 2, 3])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ key: "value" })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        expect(described_class.call("3.14", { key: "value" })).to eq(3.14)
      end

      it "works with empty options" do
        expect(described_class.call(123, {})).to eq(123.0)
      end

      it "works with nil options" do
        expect(described_class.call("2.5", nil)).to eq(2.5)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "float", default: "could not coerce into a float").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles very large floats" do
        large_float = 999_999_999_999_999_999_999.0
        expect(described_class.call(large_float)).to eq(large_float)
      end

      it "handles very small floats" do
        small_float = 0.000000000000000001
        expect(described_class.call(small_float)).to eq(small_float)
      end

      it "raises CoercionError for infinity string" do
        expect do
          described_class.call("Infinity")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end

      it "raises CoercionError for negative infinity string" do
        expect do
          described_class.call("-Infinity")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a float/)
      end
    end
  end
end
