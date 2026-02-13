# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash, type: :unit do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is nil" do
      it "returns an empty hash" do
        hash = {}

        result = coercion.call(nil)

        expect(result).to be_a(Hash)
        expect(result).to eq(hash)
      end
    end

    context "when value is already a Hash" do
      it "returns the hash unchanged" do
        hash = { key: "value", nested: { inner: "data" } }

        result = coercion.call(hash)

        expect(result).to be_a(Hash)
        expect(result).to eq(hash)
        expect(result).to be(hash)
      end

      it "returns an empty hash unchanged" do
        hash = {}

        result = coercion.call(hash)

        expect(result).to be_a(Hash)
        expect(result).to eq({})
        expect(result).to be(hash)
      end
    end

    context "when value is an Array" do
      it "converts even-length array to hash" do
        array = [:key1, "value1", :key2, "value2"]

        result = coercion.call(array)

        expect(result).to be_a(Hash)
        expect(result).to eq(key1: "value1", key2: "value2")
      end

      it "converts array with string keys to hash" do
        array = %w[name John age 30]

        result = coercion.call(array)

        expect(result).to be_a(Hash)
        expect(result).to eq("name" => "John", "age" => "30")
      end

      it "converts array with mixed types to hash" do
        array = [:symbol, 123, "string", true]

        result = coercion.call(array)

        expect(result).to be_a(Hash)
        expect(result).to eq(symbol: 123, "string" => true)
      end

      it "converts empty array to empty hash" do
        result = coercion.call([])

        expect(result).to be_a(Hash)
        expect(result).to eq({})
      end

      it "raises CoercionError for odd-length array" do
        expect { coercion.call([:key1, "value1", :key2]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "when value is a JSON string" do
      it "parses valid JSON object string" do
        json_string = '{"name": "John", "age": 30}'

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq("name" => "John", "age" => 30)
      end

      it "parses JSON string with nested objects" do
        json_string = '{"user": {"name": "John", "details": {"age": 30}}}'

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq("user" => { "name" => "John", "details" => { "age" => 30 } })
      end

      it "parses JSON string with arrays" do
        json_string = '{"tags": ["ruby", "programming"], "count": 2}'

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq("tags" => %w[ruby programming], "count" => 2)
      end

      it "parses empty JSON object" do
        result = coercion.call("{}")

        expect(result).to be_a(Hash)
        expect(result).to eq({})
      end

      it "parses JSON null string as empty hash" do
        result = coercion.call("null")

        expect(result).to be_a(Hash)
        expect(result).to eq({})
      end

      it "parses JSON null string with whitespace as empty hash" do
        result = coercion.call("  null  ")

        expect(result).to be_a(Hash)
        expect(result).to eq({})
      end

      it "raises CoercionError for invalid JSON" do
        expect { coercion.call('{"invalid": json}') }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for JSON array string" do
        expect { coercion.call('["not", "a", "hash"]') }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for JSON string primitive" do
        expect { coercion.call('"just a string"') }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for unclosed JSON" do
        expect { coercion.call('{"unclosed": "object"') }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "when value is an object that responds to to_h" do
      it "converts the object to a hash" do
        object = Object.new
        def object.to_h
          { key: "value" }
        end

        result = coercion.call(object)

        expect(result).to be_a(Hash)
        expect(result).to eq(key: "value")
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for string not starting with '{'" do
        expect { coercion.call("not json") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for integer" do
        expect { coercion.call(123) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(123.45) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for boolean true" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for boolean false" do
        expect { coercion.call(false) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for string starting with '{' but invalid JSON" do
        expect { coercion.call("{not valid json}") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with options parameter" do
      it "ignores options and converts valid hash" do
        hash = { key: "value" }

        result = coercion.call(hash, some: "option")

        expect(result).to be_a(Hash)
        expect(result).to eq(hash)
      end

      it "ignores options and converts valid array" do
        array = [:key, "value"]

        result = coercion.call(array, precision: 2)

        expect(result).to be_a(Hash)
        expect(result).to eq(key: "value")
      end

      it "ignores options and converts valid JSON string" do
        json_string = '{"test": "value"}'

        result = coercion.call(json_string, format: :json)

        expect(result).to be_a(Hash)
        expect(result).to eq("test" => "value")
      end

      it "ignores options and raises error for invalid input" do
        expect { coercion.call("invalid", some: "option") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with edge cases" do
      it "handles array with nil values" do
        array = [:key1, nil, :key2, "value"]

        result = coercion.call(array)

        expect(result).to be_a(Hash)
        expect(result).to eq(key1: nil, key2: "value")
      end

      it "handles JSON string with null values" do
        json_string = '{"key1": null, "key2": "value"}'

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq("key1" => nil, "key2" => "value")
      end

      it "handles JSON string with special characters" do
        json_string = '{"special": "\\n\\t\\r\\"", "unicode": "\\u0041"}'

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq("special" => "\n\t\r\"", "unicode" => "A")
      end

      it "handles very large JSON string" do
        large_hash = (1..100).each_with_object({}) { |i, h| h["key#{i}"] = "value#{i}" }
        json_string = large_hash.to_json

        result = coercion.call(json_string)

        expect(result).to be_a(Hash)
        expect(result).to eq(large_hash)
      end
    end
  end
end
