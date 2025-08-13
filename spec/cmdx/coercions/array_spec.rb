# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array, type: :unit do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is a JSON string starting with '['" do
      it "parses valid JSON array string" do
        result = coercion.call('["a", "b", "c"]')

        expect(result).to eq(%w[a b c])
      end

      it "parses JSON array with mixed types" do
        result = coercion.call('[1, "string", true, null]')

        expect(result).to eq([1, "string", true, nil])
      end

      it "parses empty JSON array" do
        result = coercion.call("[]")

        expect(result).to eq([])
      end

      it "parses nested JSON arrays" do
        result = coercion.call("[[1, 2], [3, 4]]")

        expect(result).to eq([[1, 2], [3, 4]])
      end

      it "parses JSON array with objects" do
        result = coercion.call('[{"key": "value"}, {"number": 42}]')

        expect(result).to eq([{ "key" => "value" }, { "number" => 42 }])
      end

      context "with invalid JSON" do
        it "raises JSON::ParserError for malformed JSON" do
          expect { coercion.call("[invalid json") }
            .to raise_error(JSON::ParserError)
        end

        it "raises JSON::ParserError for incomplete array" do
          expect { coercion.call("[1, 2,") }
            .to raise_error(JSON::ParserError)
        end

        it "raises JSON::ParserError for unquoted strings" do
          expect { coercion.call("[unquoted, string]") }
            .to raise_error(JSON::ParserError)
        end
      end
    end

    context "when value is a string not starting with '['" do
      it "wraps single string value in array" do
        result = coercion.call("hello")

        expect(result).to eq(["hello"])
      end

      it "wraps empty string in array" do
        result = coercion.call("")

        expect(result).to eq([""])
      end

      it "wraps string starting with other characters" do
        result = coercion.call("{key: value}")

        expect(result).to eq(["{key: value}"])
      end

      it "wraps numeric string in array" do
        result = coercion.call("123")

        expect(result).to eq(["123"])
      end
    end

    context "when value is already an array" do
      it "returns the array unchanged" do
        input = [1, 2, 3]

        result = coercion.call(input)

        expect(result).to eq([1, 2, 3])
      end

      it "returns empty array unchanged" do
        input = []

        result = coercion.call(input)

        expect(result).to eq([])
      end

      it "returns nested array unchanged" do
        input = [[1, 2], [3, 4]]

        result = coercion.call(input)

        expect(result).to eq([[1, 2], [3, 4]])
      end
    end

    context "when value is nil" do
      it "converts nil to empty array" do
        result = coercion.call(nil)

        expect(result).to eq([])
      end
    end

    context "when value is a number" do
      it "wraps integer in array" do
        result = coercion.call(42)

        expect(result).to eq([42])
      end

      it "wraps float in array" do
        result = coercion.call(3.14)

        expect(result).to eq([3.14])
      end

      it "wraps zero in array" do
        result = coercion.call(0)

        expect(result).to eq([0])
      end
    end

    context "when value is a boolean" do
      it "wraps true in array" do
        result = coercion.call(true)

        expect(result).to eq([true])
      end

      it "wraps false in array" do
        result = coercion.call(false)

        expect(result).to eq([false])
      end
    end

    context "when value is a hash" do
      it "converts hash to array of key-value pairs" do
        input = { key: "value" }

        result = coercion.call(input)

        expect(result).to eq([[:key, "value"]])
      end

      it "converts empty hash to empty array" do
        result = coercion.call({})

        expect(result).to eq([])
      end
    end

    context "when value is an enumerable object" do
      it "converts range to array" do
        result = coercion.call(1..3)

        expect(result).to eq([1, 2, 3])
      end

      it "converts set to array" do
        input = Set.new([1, 2, 3])

        result = coercion.call(input)

        expect(result).to eq([1, 2, 3])
      end
    end

    context "with options parameter" do
      it "ignores options when processing JSON string" do
        result = coercion.call('["a", "b"]', { unused: "option" })

        expect(result).to eq(%w[a b])
      end

      it "ignores options when wrapping non-JSON values" do
        result = coercion.call("hello", { unused: "option" })

        expect(result).to eq(["hello"])
      end

      it "works with empty options hash" do
        result = coercion.call([1, 2, 3], {})

        expect(result).to eq([1, 2, 3])
      end
    end
  end
end
