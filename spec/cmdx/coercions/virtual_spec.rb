# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Virtual do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("value")).to eq("value")
    end
  end

  describe "#call" do
    context "with string values" do
      it "returns strings unchanged" do
        result = coercion.call("hello")

        expect(result).to eq("hello")
      end

      it "returns empty strings unchanged" do
        result = coercion.call("")

        expect(result).to eq("")
      end

      it "returns strings with special characters unchanged" do
        result = coercion.call("hello\nworld\t!")

        expect(result).to eq("hello\nworld\t!")
      end
    end

    context "with numeric values" do
      it "returns integers unchanged" do
        result = coercion.call(123)

        expect(result).to eq(123)
      end

      it "returns floats unchanged" do
        result = coercion.call(3.14)

        expect(result).to eq(3.14)
      end

      it "returns zero unchanged" do
        result = coercion.call(0)

        expect(result).to eq(0)
      end

      it "returns negative numbers unchanged" do
        result = coercion.call(-42)

        expect(result).to eq(-42)
      end
    end

    context "with boolean values" do
      it "returns true unchanged" do
        result = coercion.call(true)

        expect(result).to eq(true)
      end

      it "returns false unchanged" do
        result = coercion.call(false)

        expect(result).to eq(false)
      end
    end

    context "with nil values" do
      it "returns nil unchanged" do
        result = coercion.call(nil)

        expect(result).to be_nil
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
    end

    context "with hash values" do
      it "returns hashes unchanged" do
        input = { a: 1, b: 2 }
        result = coercion.call(input)

        expect(result).to eq({ a: 1, b: 2 })
      end

      it "returns empty hashes unchanged" do
        input = {}
        result = coercion.call(input)

        expect(result).to eq({})
      end
    end

    context "with complex objects" do
      it "returns objects unchanged" do
        input = Object.new
        result = coercion.call(input)

        expect(result).to equal(input)
      end

      it "returns structs unchanged" do
        input = Struct.new(:name, :age).new("John", 30)
        result = coercion.call(input)

        expect(result).to equal(input)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call("test", { some: "option" })

        expect(result).to eq("test")
      end

      it "returns value unchanged regardless of options" do
        result = coercion.call(42, { complex: { nested: "options" } })

        expect(result).to eq(42)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessVirtualTask") do
        required :data, type: :virtual
        optional :metadata, type: :virtual, default: "default_meta"

        def call
          context.processed_data = data
          context.metadata_info = metadata
        end
      end
    end

    it "preserves original parameter values" do
      result = task_class.call(data: { complex: "object" })

      expect(result).to be_success
      expect(result.context.processed_data).to eq({ complex: "object" })
    end

    it "works with string parameters" do
      result = task_class.call(data: "raw_string")

      expect(result).to be_success
      expect(result.context.processed_data).to eq("raw_string")
    end

    it "works with array parameters" do
      result = task_class.call(data: [1, 2, 3])

      expect(result).to be_success
      expect(result.context.processed_data).to eq([1, 2, 3])
    end

    it "preserves nil values" do
      result = task_class.call(data: nil)

      expect(result).to be_success
      expect(result.context.processed_data).to be_nil
    end

    it "uses default values for optional virtual parameters" do
      result = task_class.call(data: "test")

      expect(result).to be_success
      expect(result.context.metadata_info).to eq("default_meta")
    end

    it "preserves optional parameters when provided" do
      result = task_class.call(data: "test", metadata: { custom: "value" })

      expect(result).to be_success
      expect(result.context.metadata_info).to eq({ custom: "value" })
    end
  end
end
