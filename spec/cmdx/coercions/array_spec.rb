# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array do
  describe "#call" do
    context "with array values" do
      it "returns array unchanged" do
        array = [1, 2, 3]
        expect(described_class.call(array)).to eq(array)
      end

      it "returns empty array unchanged" do
        expect(described_class.call([])).to eq([])
      end

      it "returns nested array unchanged" do
        array = [[1, 2], [3, 4]]
        expect(described_class.call(array)).to eq(array)
      end

      it "returns mixed type array unchanged" do
        array = [1, "string", :symbol, { key: "value" }]
        expect(described_class.call(array)).to eq(array)
      end
    end

    context "with string values" do
      it "converts regular string to array" do
        expect(described_class.call("string")).to eq(["string"])
      end

      it "converts empty string to array" do
        expect(described_class.call("")).to eq([""])
      end

      it "converts numeric string to array" do
        expect(described_class.call("123")).to eq(["123"])
      end

      it "parses JSON array string" do
        expect(described_class.call("[1, 2, 3]")).to eq([1, 2, 3])
      end

      it "parses JSON string array" do
        expect(described_class.call('["a", "b", "c"]')).to eq(%w[a b c])
      end
    end

    context "with numeric values" do
      it "converts integer to array" do
        expect(described_class.call(123)).to eq([123])
      end

      it "converts float to array" do
        expect(described_class.call(3.14)).to eq([3.14])
      end

      it "converts zero to array" do
        expect(described_class.call(0)).to eq([0])
      end
    end

    context "with boolean values" do
      it "converts true to array" do
        expect(described_class.call(true)).to eq([true])
      end

      it "converts false to array" do
        expect(described_class.call(false)).to eq([false])
      end
    end

    context "with nil values" do
      it "converts nil to empty array" do
        expect(described_class.call(nil)).to eq([])
      end
    end

    context "with hash values" do
      it "converts empty hash to array of pairs" do
        expect(described_class.call({})).to eq([])
      end

      it "converts non-empty hash to array of pairs" do
        result = described_class.call({ key: "value" })
        expect(result).to eq([[:key, "value"]])
      end
    end

    context "with symbol values" do
      it "converts symbol to array" do
        expect(described_class.call(:test)).to eq([:test])
      end
    end

    context "with object values" do
      it "converts object to array" do
        obj = Object.new
        expect(described_class.call(obj)).to eq([obj])
      end

      it "converts class to array" do
        expect(described_class.call(String)).to eq([String])
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        array = [1, 2, 3]
        expect(described_class.call(array, { key: "value" })).to eq(array)
      end

      it "works with empty options" do
        array = %w[a b c]
        expect(described_class.call(array, {})).to eq(array)
      end

      it "works with nil options" do
        array = %i[x y z]
        expect(described_class.call(array, nil)).to eq(array)
      end
    end

    context "with edge cases" do
      it "handles array with single element" do
        array = ["single"]
        expect(described_class.call(array)).to eq(array)
      end

      it "handles array with nil elements" do
        array = [nil, "value", nil]
        expect(described_class.call(array)).to eq(array)
      end

      it "handles array with duplicate elements" do
        array = [1, 1, 2, 2, 3, 3]
        expect(described_class.call(array)).to eq(array)
      end

      it "handles deeply nested arrays" do
        array = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
        expect(described_class.call(array)).to eq(array)
      end

      it "handles array with complex objects" do
        array = [{ a: 1 }, [1, 2], "string", :symbol, 123]
        expect(described_class.call(array)).to eq(array)
      end
    end
  end
end
