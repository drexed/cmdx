# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call('{"a": 1}')).to eq({ "a" => 1 })
    end
  end

  describe "#call" do
    context "with hash values" do
      it "returns hashes unchanged" do
        input = { "a" => 1, "b" => 2 }
        result = coercion.call(input)

        expect(result).to eq({ "a" => 1, "b" => 2 })
      end

      it "returns empty hashes unchanged" do
        input = {}
        result = coercion.call(input)

        expect(result).to eq({})
      end

      it "returns hashes with mixed types unchanged" do
        input = { "string" => "value", "number" => 42, "boolean" => true, "null" => nil }
        result = coercion.call(input)

        expect(result).to eq({ "string" => "value", "number" => 42, "boolean" => true, "null" => nil })
      end

      it "returns hashes with symbol keys unchanged" do
        input = { a: 1, b: 2 }
        result = coercion.call(input)

        expect(result).to eq({ a: 1, b: 2 })
      end
    end

    context "with ActionController::Parameters" do
      it "returns ActionController::Parameters unchanged" do
        # Create a mock object that responds to class.name as "ActionController::Parameters"
        params = double("ActionController::Parameters")
        allow(params).to receive(:class).and_return(double(name: "ActionController::Parameters"))

        result = coercion.call(params)

        expect(result).to eq(params)
      end
    end

    context "with array values" do
      it "converts arrays to hashes using splat operator" do
        input = ["a", 1, "b", 2]
        result = coercion.call(input)

        expect(result).to eq({ "a" => 1, "b" => 2 })
      end

      it "converts empty arrays to empty hashes" do
        input = []
        result = coercion.call(input)

        expect(result).to eq({})
      end

      it "converts arrays with symbol keys" do
        input = [:a, 1, :b, 2]
        result = coercion.call(input)

        expect(result).to eq({ a: 1, b: 2 })
      end

      it "raises CoercionError for arrays with odd number of elements" do
        expect { coercion.call(["a", 1, "b"]) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with JSON string values" do
      it "parses valid JSON hash strings" do
        result = coercion.call('{"a": 1, "b": 2}')

        expect(result).to eq({ "a" => 1, "b" => 2 })
      end

      it "parses JSON hashes with mixed types" do
        result = coercion.call('{"string": "value", "number": 42, "boolean": true, "null": null}')

        expect(result).to eq({ "string" => "value", "number" => 42, "boolean" => true, "null" => nil })
      end

      it "parses nested JSON hashes" do
        result = coercion.call('{"outer": {"inner": "value"}}')

        expect(result).to eq({ "outer" => { "inner" => "value" } })
      end

      it "parses empty JSON hashes" do
        result = coercion.call("{}")

        expect(result).to eq({})
      end

      it "parses JSON hashes with arrays as values" do
        result = coercion.call('{"tags": ["ruby", "rails"], "count": 2}')

        expect(result).to eq({ "tags" => %w[ruby rails], "count" => 2 })
      end

      it "raises CoercionError for invalid JSON hashes" do
        expect { coercion.call('{"invalid": json}') }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for incomplete JSON hashes" do
        expect { coercion.call('{"incomplete"') }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for strings with only opening brace" do
        expect { coercion.call("{") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for strings that start with { but aren't valid JSON" do
        expect { coercion.call("{not json") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for strings that start with { but are not hashes" do
        expect { coercion.call("{array Array}") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with non-JSON string values" do
      it "raises CoercionError for regular strings" do
        expect { coercion.call("hello") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for strings that contain braces but don't start with {" do
        expect { coercion.call("test {with braces}") }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for strings with leading whitespace that look like JSON" do
        expect { coercion.call('  {"a": 1}  ') }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for JSON arrays that start with [" do
        expect { coercion.call('["a", "b", "c"]') }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with numeric values" do
      it "raises CoercionError for integers" do
        expect { coercion.call(123) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for floats" do
        expect { coercion.call(3.14) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for zero" do
        expect { coercion.call(0) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect { coercion.call(true) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for false" do
        expect { coercion.call(false) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with complex objects" do
      it "raises CoercionError for custom objects" do
        input = Object.new
        expect { coercion.call(input) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end

      it "raises CoercionError for structs" do
        input = Struct.new(:name, :age).new("John", 30)
        expect { coercion.call(input) }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "with options parameter" do
      it "ignores options parameter for hash input" do
        input = { "a" => 1 }
        result = coercion.call(input, { some: "option" })

        expect(result).to eq({ "a" => 1 })
      end

      it "ignores options parameter for JSON input" do
        result = coercion.call('{"a": 1}', { some: "option" })

        expect(result).to eq({ "a" => 1 })
      end

      it "ignores options parameter for array input" do
        result = coercion.call(["a", 1], { some: "option" })

        expect(result).to eq({ "a" => 1 })
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessConfigTask") do
        required :config, type: :hash
        optional :settings, type: :hash, default: {}

        def call
          context.config_keys = config.keys.map(&:to_s)
          context.settings_count = settings.size
        end
      end
    end

    it "coerces JSON string parameters to hashes" do
      result = task_class.call(config: '{"database": "postgres", "port": 5432}')

      expect(result).to be_success
      expect(result.context.config_keys).to contain_exactly("database", "port")
    end

    it "coerces array parameters to hashes" do
      result = task_class.call(config: ["env", "production", "debug", false])

      expect(result).to be_success
      expect(result.context.config_keys).to contain_exactly("env", "debug")
    end

    it "handles hash parameters unchanged" do
      result = task_class.call(config: { database: "mysql", port: 3306 })

      expect(result).to be_success
      expect(result.context.config_keys).to contain_exactly("database", "port")
    end

    it "uses default values for optional hash parameters" do
      result = task_class.call(config: { "key" => "value" })

      expect(result).to be_success
      expect(result.context.settings_count).to eq(0)
    end

    it "fails with CoercionError for invalid hash parameters" do
      result = task_class.call(config: "invalid_string")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a hash")
    end

    it "fails with CoercionError for odd-length arrays" do
      result = task_class.call(config: ["a", 1, "b"])

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a hash")
    end

    it "fails with CoercionError for invalid JSON" do
      result = task_class.call(config: '{"invalid": json}')

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a hash")
    end
  end
end
