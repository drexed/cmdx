# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("value")).to eq(["value"])
    end
  end

  describe "#call" do
    context "with JSON string values" do
      it "parses valid JSON array strings" do
        result = coercion.call('["a", "b", "c"]')
        expect(result).to eq(%w[a b c])
      end

      it "parses JSON arrays with mixed types" do
        result = coercion.call('[1, "string", true, null]')
        expect(result).to eq([1, "string", true, nil])
      end

      it "parses nested JSON arrays" do
        result = coercion.call('[["a", "b"], ["c", "d"]]')
        expect(result).to eq([%w[a b], %w[c d]])
      end

      it "parses empty JSON arrays" do
        result = coercion.call("[]")
        expect(result).to eq([])
      end

      it "parses JSON arrays with objects" do
        result = coercion.call('[{"name": "test"}, {"id": 1}]')
        expect(result).to eq([{ "name" => "test" }, { "id" => 1 }])
      end

      it "raises JSON::ParserError for invalid JSON arrays" do
        expect { coercion.call('["invalid", json}') }.to raise_error(JSON::ParserError)
      end

      it "raises JSON::ParserError for incomplete JSON arrays" do
        expect { coercion.call('["incomplete"') }.to raise_error(JSON::ParserError)
      end

      it "raises JSON::ParserError for strings with only opening bracket" do
        expect { coercion.call("[") }.to raise_error(JSON::ParserError)
      end

      it "raises JSON::ParserError for strings that start with [ but aren't valid JSON" do
        expect { coercion.call("[not json") }.to raise_error(JSON::ParserError)
      end

      it "raises JSON::ParserError for strings that start with [ but are not arrays" do
        expect { coercion.call("[object Object]") }.to raise_error(JSON::ParserError)
      end
    end

    context "with non-JSON string values" do
      it "converts regular strings to single-element arrays" do
        result = coercion.call("hello")
        expect(result).to eq(["hello"])
      end

      it "converts empty strings to single-element arrays" do
        result = coercion.call("")
        expect(result).to eq([""])
      end

      it "converts strings that contain brackets but don't start with [" do
        result = coercion.call("test [with brackets]")
        expect(result).to eq(["test [with brackets]"])
      end

      it "handles whitespace-only strings" do
        result = coercion.call("   ")
        expect(result).to eq(["   "])
      end

      it "handles strings with leading whitespace that look like JSON" do
        result = coercion.call('  ["a", "b"]  ')
        expect(result).to eq(['  ["a", "b"]  '])
      end
    end

    context "with array values" do
      it "returns arrays unchanged" do
        input = %w[a b c]
        result = coercion.call(input)
        expect(result).to eq(%w[a b c])
      end

      it "returns empty arrays unchanged" do
        input = []
        result = coercion.call(input)
        expect(result).to eq([])
      end

      it "returns arrays with mixed types unchanged" do
        input = [1, "string", true, nil]
        result = coercion.call(input)
        expect(result).to eq([1, "string", true, nil])
      end
    end

    context "with nil values" do
      it "converts nil to empty array" do
        result = coercion.call(nil)
        expect(result).to eq([])
      end
    end

    context "with numeric values" do
      it "converts integers to single-element arrays" do
        result = coercion.call(123)
        expect(result).to eq([123])
      end

      it "converts floats to single-element arrays" do
        result = coercion.call(3.14)
        expect(result).to eq([3.14])
      end

      it "converts zero to single-element arrays" do
        result = coercion.call(0)
        expect(result).to eq([0])
      end
    end

    context "with boolean values" do
      it "converts true to single-element arrays" do
        result = coercion.call(true)
        expect(result).to eq([true])
      end

      it "converts false to single-element arrays" do
        result = coercion.call(false)
        expect(result).to eq([false])
      end
    end

    context "with hash values" do
      it "converts hashes to arrays of key-value pairs" do
        input = { a: 1, b: 2 }
        result = coercion.call(input)
        expect(result).to eq([[:a, 1], [:b, 2]])
      end

      it "converts empty hashes to empty arrays" do
        input = {}
        result = coercion.call(input)
        expect(result).to eq([])
      end
    end

    context "with complex objects" do
      it "converts objects to single-element arrays" do
        input = Object.new
        result = coercion.call(input)
        expect(result).to eq([input])
      end

      it "converts structs to arrays of their values" do
        input = Struct.new(:name, :age).new("John", 30)
        result = coercion.call(input)
        expect(result).to eq(["John", 30])
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call("test", { some: "option" })
        expect(result).to eq(["test"])
      end

      it "processes JSON with options parameter" do
        result = coercion.call('["a", "b"]', { some: "option" })
        expect(result).to eq(%w[a b])
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def self.name
          "ProcessTagsTask"
        end

        required :tags, type: :array
        optional :categories, type: :array, default: []

        def call
          context.processed_tags = tags.map(&:downcase)
          context.categories_count = categories.length
        end
      end
    end

    it "coerces JSON string parameters to arrays" do
      result = task_class.call(tags: '["Ruby", "Rails", "CMDx"]')

      expect(result).to be_success
      expect(result.context.processed_tags).to eq(%w[ruby rails cmdx])
    end

    it "coerces regular values to single-element arrays" do
      result = task_class.call(tags: "Ruby")

      expect(result).to be_success
      expect(result.context.processed_tags).to eq(["ruby"])
    end

    it "handles array parameters unchanged" do
      result = task_class.call(tags: %w[Ruby Rails])

      expect(result).to be_success
      expect(result.context.processed_tags).to eq(%w[ruby rails])
    end

    it "uses default values for optional array parameters" do
      result = task_class.call(tags: ["Ruby"])

      expect(result).to be_success
      expect(result.context.categories_count).to eq(0)
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(tags: ["Ruby"], categories: '["Web", "Framework"]')

      expect(result).to be_success
      expect(result.context.categories_count).to eq(2)
    end

    it "fails when coercion fails for invalid JSON" do
      result = task_class.call(tags: '["invalid json')

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("JSON::ParserError")
      expect(result.metadata[:original_exception]).to be_a(JSON::ParserError)
    end
  end
end
