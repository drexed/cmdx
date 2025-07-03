# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash do
  describe "#call" do
    context "with hash values" do
      it "returns hash unchanged" do
        hash = { key: "value", number: 123 }
        expect(described_class.call(hash)).to eq(hash)
      end

      it "returns empty hash unchanged" do
        expect(described_class.call({})).to eq({})
      end

      it "returns nested hash unchanged" do
        hash = { outer: { inner: "value" } }
        expect(described_class.call(hash)).to eq(hash)
      end
    end

    context "with ActionController::Parameters" do
      it "returns ActionController::Parameters unchanged" do
        klass = Class.new do
          def self.name
            "ActionController::Parameters"
          end
        end

        acp = klass.new

        expect(described_class.call(acp)).to eq(acp)
      end
    end

    context "with JSON string values" do
      it "parses valid JSON string" do
        json_string = '{"key":"value","number":123}'
        expected = { "key" => "value", "number" => 123 }
        expect(described_class.call(json_string)).to eq(expected)
      end

      it "parses empty JSON object" do
        expect(described_class.call("{}")).to eq({})
      end

      it "parses nested JSON" do
        json_string = '{"outer":{"inner":"value"}}'
        expected = { "outer" => { "inner" => "value" } }
        expect(described_class.call(json_string)).to eq(expected)
      end

      it "parses JSON with arrays" do
        json_string = '{"items":[1,2,3]}'
        expected = { "items" => [1, 2, 3] }
        expect(described_class.call(json_string)).to eq(expected)
      end

      it "raises CoercionError for invalid JSON" do
        expect do
          described_class.call('{"invalid":json}')
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for malformed JSON" do
        expect do
          described_class.call('{"key":"value"')
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with array values" do
      it "converts even-length array to hash" do
        array = [:key1, "value1", :key2, "value2"]
        expected = { key1: "value1", key2: "value2" }
        expect(described_class.call(array)).to eq(expected)
      end

      it "converts empty array to empty hash" do
        expect(described_class.call([])).to eq({})
      end

      it "converts mixed type array to hash" do
        array = ["string_key", 123, :symbol_key, "value"]
        expected = { "string_key" => 123, symbol_key: "value" }
        expect(described_class.call(array)).to eq(expected)
      end

      it "raises CoercionError for odd-length array" do
        expect do
          described_class.call([:key1, "value1", :key2])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with string values that don't start with '{'" do
      it "raises CoercionError for regular string" do
        expect do
          described_class.call("regular string")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for string starting with '['" do
        expect do
          described_class.call('["array","string"]')
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with numeric values" do
      it "raises CoercionError for integer" do
        expect do
          described_class.call(123)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for float" do
        expect do
          described_class.call(3.14)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for zero" do
        expect do
          described_class.call(0)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end

      it "raises CoercionError for class" do
        expect do
          described_class.call(String)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        hash = { key: "value" }
        expect(described_class.call(hash, { option: "ignored" })).to eq(hash)
      end

      it "works with empty options" do
        hash = { key: "value" }
        expect(described_class.call(hash, {})).to eq(hash)
      end

      it "works with nil options" do
        hash = { key: "value" }
        expect(described_class.call(hash, nil)).to eq(hash)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "hash", default: "could not coerce into a hash").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles hash with symbol keys" do
        hash = { symbol_key: "value" }
        expect(described_class.call(hash)).to eq(hash)
      end

      it "handles hash with string keys" do
        hash = { "string_key" => "value" }
        expect(described_class.call(hash)).to eq(hash)
      end

      it "handles hash with mixed key types" do
        hash = { :symbol => "value1", "string" => "value2" }
        expect(described_class.call(hash)).to eq(hash)
      end

      it "handles JSON with special characters" do
        json_string = '{"key with spaces":"value with\nnewlines"}'
        expected = { "key with spaces" => "value with\nnewlines" }
        expect(described_class.call(json_string)).to eq(expected)
      end

      it "raises CoercionError for array with nil values" do
        expect do
          described_class.call([:key, nil, :other_key])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a hash/)
      end
    end
  end
end
