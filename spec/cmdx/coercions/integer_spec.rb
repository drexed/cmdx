# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Integer do
  describe "#call" do
    context "with integer values" do
      it "returns integer unchanged" do
        expect(described_class.call(123)).to eq(123)
      end

      it "returns negative integer unchanged" do
        expect(described_class.call(-456)).to eq(-456)
      end

      it "returns zero unchanged" do
        expect(described_class.call(0)).to eq(0)
      end
    end

    context "with string values" do
      it "converts numeric string to integer" do
        expect(described_class.call("123")).to eq(123)
      end

      it "converts negative string to integer" do
        expect(described_class.call("-456")).to eq(-456)
      end

      it "converts zero string to integer" do
        expect(described_class.call("0")).to eq(0)
      end

      it "converts hexadecimal string to integer" do
        expect(described_class.call("0x10")).to eq(16)
      end

      it "converts binary string to integer" do
        expect(described_class.call("0b1010")).to eq(10)
      end

      it "converts octal string to integer" do
        expect(described_class.call("0o12")).to eq(10)
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "converts string with spaces to integer" do
        expect(described_class.call("  123  ")).to eq(123)
      end

      it "raises CoercionError for mixed alphanumeric string" do
        expect do
          described_class.call("123abc")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with float values" do
      it "converts positive float to integer" do
        expect(described_class.call(3.14)).to eq(3)
      end

      it "converts negative float to integer" do
        expect(described_class.call(-2.7)).to eq(-2)
      end

      it "converts zero float to integer" do
        expect(described_class.call(0.0)).to eq(0)
      end

      it "truncates decimal part" do
        expect(described_class.call(9.99)).to eq(9)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([1, 2, 3])
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ key: "value" })
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for numeric symbol" do
        expect do
          described_class.call(:"123")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for class" do
        expect do
          described_class.call(String)
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with special numeric formats" do
      it "raises CoercionError for scientific notation" do
        expect do
          described_class.call("1e2")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for negative scientific notation" do
        expect do
          described_class.call("-1e2")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end

      it "raises CoercionError for invalid scientific notation" do
        expect do
          described_class.call("1e2.5")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        expect(described_class.call("123", { key: "value" })).to eq(123)
      end

      it "works with empty options" do
        expect(described_class.call(456, {})).to eq(456)
      end

      it "works with nil options" do
        expect(described_class.call("789", nil)).to eq(789)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_an", type: "integer", default: "could not coerce into an integer").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles very large integers" do
        large_int = 999_999_999_999_999_999_999
        expect(described_class.call(large_int)).to eq(large_int)
      end

      it "handles very large string integers" do
        expect(described_class.call("999999999999999999999")).to eq(999_999_999_999_999_999_999)
      end

      it "raises CoercionError for float strings" do
        expect do
          described_class.call("3.14")
        end.to raise_error(CMDx::CoercionError, /could not coerce into an integer/)
      end
    end
  end
end
