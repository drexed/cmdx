# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  describe "#call" do
    context "with truthy string values" do
      it "converts 'true' to true" do
        expect(described_class.call("true")).to be(true)
      end

      it "converts 'True' to true" do
        expect(described_class.call("True")).to be(true)
      end

      it "converts 'TRUE' to true" do
        expect(described_class.call("TRUE")).to be(true)
      end

      it "converts 't' to true" do
        expect(described_class.call("t")).to be(true)
      end

      it "converts 'T' to true" do
        expect(described_class.call("T")).to be(true)
      end

      it "converts 'yes' to true" do
        expect(described_class.call("yes")).to be(true)
      end

      it "converts 'YES' to true" do
        expect(described_class.call("YES")).to be(true)
      end

      it "converts 'y' to true" do
        expect(described_class.call("y")).to be(true)
      end

      it "converts 'Y' to true" do
        expect(described_class.call("Y")).to be(true)
      end

      it "converts '1' to true" do
        expect(described_class.call("1")).to be(true)
      end
    end

    context "with falsy string values" do
      it "converts 'false' to false" do
        expect(described_class.call("false")).to be(false)
      end

      it "converts 'False' to false" do
        expect(described_class.call("False")).to be(false)
      end

      it "converts 'FALSE' to false" do
        expect(described_class.call("FALSE")).to be(false)
      end

      it "converts 'f' to false" do
        expect(described_class.call("f")).to be(false)
      end

      it "converts 'F' to false" do
        expect(described_class.call("F")).to be(false)
      end

      it "converts 'no' to false" do
        expect(described_class.call("no")).to be(false)
      end

      it "converts 'NO' to false" do
        expect(described_class.call("NO")).to be(false)
      end

      it "converts 'n' to false" do
        expect(described_class.call("n")).to be(false)
      end

      it "converts 'N' to false" do
        expect(described_class.call("N")).to be(false)
      end

      it "converts '0' to false" do
        expect(described_class.call("0")).to be(false)
      end
    end

    context "with boolean values" do
      it "converts true to true" do
        expect(described_class.call(true)).to be(true)
      end

      it "converts false to false" do
        expect(described_class.call(false)).to be(false)
      end
    end

    context "with numeric values" do
      it "converts 1 to true" do
        expect(described_class.call(1)).to be(true)
      end

      it "converts 0 to false" do
        expect(described_class.call(0)).to be(false)
      end

      it "raises CoercionError for other integers" do
        expect do
          described_class.call(2)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for negative integers" do
        expect do
          described_class.call(-1)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for floats" do
        expect do
          described_class.call(1.5)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with invalid string values" do
      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for numeric string" do
        expect do
          described_class.call("123")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for whitespace string" do
        expect do
          described_class.call("   ")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([1, 2, 3])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ key: "value" })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with symbol values" do
      it "converts :true to true" do
        expect(described_class.call(true)).to be(true)
      end

      it "converts :false to false" do
        expect(described_class.call(false)).to be(false)
      end

      it "converts :yes to true" do
        expect(described_class.call(:yes)).to be(true)
      end

      it "converts :no to false" do
        expect(described_class.call(:no)).to be(false)
      end

      it "raises CoercionError for invalid symbol" do
        expect do
          described_class.call(:invalid)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a boolean/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        expect(described_class.call("true", { key: "value" })).to be(true)
      end

      it "works with empty options" do
        expect(described_class.call("false", {})).to be(false)
      end

      it "works with nil options" do
        expect(described_class.call("yes", nil)).to be(true)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "boolean", default: "could not coerce into a boolean").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end
  end
end
