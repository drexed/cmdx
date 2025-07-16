# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterEvaluator do
  subject(:evaluator) { described_class.new(task_instance, parameter) }

  let(:task_class) { create_simple_task(name: "TestTask") }
  let(:task_instance) { task_class.new }
  let(:parameter) { CMDx::Parameter.new(:test_param, klass: task_class) }

  describe ".call" do
    it "creates instance and calls #call method" do
      allow(described_class).to receive(:new).with(task_instance, parameter).and_return(evaluator)
      allow(evaluator).to receive(:call).and_return("evaluated_value")

      result = described_class.call(task_instance, parameter)

      expect(result).to eq("evaluated_value")
    end

    it "passes task and parameter to new instance" do
      expect(described_class).to receive(:new).with(task_instance, parameter).and_return(evaluator)
      allow(evaluator).to receive(:call).and_return("result")

      described_class.call(task_instance, parameter)
    end
  end

  describe "#initialize" do
    it "sets task and parameter attributes" do
      evaluator = described_class.new(task_instance, parameter)

      expect(evaluator.task).to eq(task_instance)
      expect(evaluator.parameter).to eq(parameter)
    end
  end

  describe "#call" do
    it "applies coercion and validation, then returns the coerced value" do
      allow(evaluator).to receive(:coerce!).and_return("coerced_value")
      allow(evaluator).to receive(:validate!)

      result = evaluator.call

      expect(result).to eq("coerced_value")
      expect(evaluator).to have_received(:validate!)
    end
  end

  describe "integration with basic parameter evaluation" do
    let(:task_class) do
      create_task_class(name: "BasicTask") do
        required :name, type: :string
        optional :age, type: :integer, default: 25

        def call
          context.name = name
          context.age = age
        end
      end
    end

    it "evaluates required string parameters" do
      result = task_class.call(name: "John")

      expect(result).to be_successful_task
      expect(result.context.name).to eq("John")
      expect(result.context.age).to eq(25)
    end

    it "fails when required parameter is missing" do
      result = task_class.call(age: 30)

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("is a required parameter")
    end

    it "handles type coercion" do
      result = task_class.call(name: 123, age: "30")

      expect(result).to be_successful_task
      expect(result.context.name).to eq("123")
      expect(result.context.age).to eq(30)
    end

    it "handles coercion failures" do
      task_class = create_task_class(name: "CoercionTask") do
        required :count, type: :integer

        def call
          context.count = count
        end
      end

      result = task_class.call(count: "not_a_number")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("could not coerce into an integer")
    end

    it "handles validation failures" do
      task_class = create_task_class(name: "ValidationTask") do
        required :email, type: :string, format: { with: /@/ }

        def call
          context.email = email
        end
      end

      result = task_class.call(email: "invalid_email")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("is an invalid format")
    end

    it "handles optional parameters with defaults" do
      task_class = create_task_class(name: "DefaultTask") do
        optional :name, type: :string, default: "Anonymous"

        def call
          context.name = name
        end
      end

      result = task_class.call({})

      expect(result).to be_successful_task
      expect(result.context.name).to eq("Anonymous")
    end

    it "handles optional string parameters that become empty strings" do
      task_class = create_task_class(name: "OptionalStringTask") do
        optional :nickname, type: :string

        def call
          context.nickname = nickname
        end
      end

      result = task_class.call({})

      expect(result).to be_successful_task
      expect(result.context.nickname).to eq("")
    end

    it "evaluates proc defaults" do
      task_class = create_task_class(name: "ProcDefaultTask") do
        optional :timestamp, type: :string, default: -> { "generated_value" }

        def call
          context.timestamp = timestamp
        end
      end

      result = task_class.call({})

      expect(result).to be_successful_task
      expect(result.context.timestamp).to eq("generated_value")
    end
  end
end
