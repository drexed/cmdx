# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercion do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      allow_any_instance_of(described_class).to receive(:call).with("test", {}).and_return("delegated")

      result = described_class.call("test")

      expect(result).to eq("delegated")
    end

    it "passes value and options to instance call method" do
      options = { some: "option" }
      allow_any_instance_of(described_class).to receive(:call).with("value", options).and_return("result")

      result = described_class.call("value", options)

      expect(result).to eq("result")
    end

    it "passes empty options hash when not provided" do
      allow_any_instance_of(described_class).to receive(:call).with("value", {}).and_return("result")

      result = described_class.call("value")

      expect(result).to eq("result")
    end
  end

  describe "#call" do
    it "raises UndefinedCallError with descriptive message" do
      expect { coercion.call("value") }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Coercion"
      )
    end
  end

  describe "subclass implementation" do
    let(:working_coercion_class) do
      Class.new(described_class) do
        def call(value, _options = {})
          "processed_#{value}"
        end
      end
    end

    let(:broken_coercion_class) do
      Class.new(described_class) do
        # Intentionally doesn't implement call method
      end
    end

    it "works when subclass properly implements call method" do
      result = working_coercion_class.call("test")

      expect(result).to eq("processed_test")
    end

    it "raises error when subclass doesn't implement call method" do
      expect { broken_coercion_class.call("test") }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "integration with task system" do
    let(:task_class) do
      create_task_class(name: "SimpleCoercionTask") do
        required :input, type: :string

        def call
          context.processed_input = input
        end
      end
    end

    it "works with built-in coercions in task parameters" do
      result = task_class.call(input: 123)

      expect(result).to be_successful_task
      expect(result.context.processed_input).to eq("123")
    end

    it "fails when invalid coercion type is used" do
      task_class = create_task_class(name: "InvalidCoercionTask") do
        required :input, type: :nonexistent_type

        def call
          context.processed_input = input
        end
      end

      result = task_class.call(input: "test")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("unknown coercion nonexistent_type")
      expect(result.metadata[:original_exception]).to be_a(CMDx::UnknownCoercionError)
    end
  end
end
