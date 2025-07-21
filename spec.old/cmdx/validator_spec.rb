# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validator do
  subject(:validator) { described_class.new }

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      allow_any_instance_of(described_class).to receive(:call).with("test", {}).and_return("delegated")

      result = described_class.call("test")

      expect(result).to eq("delegated")
    end

    it "passes value and options to instance call method" do
      options = { min_length: 5 }
      allow_any_instance_of(described_class).to receive(:call).with("value", options).and_return("validated")

      result = described_class.call("value", options)

      expect(result).to eq("validated")
    end

    it "passes empty options hash when not provided" do
      allow_any_instance_of(described_class).to receive(:call).with("value", {}).and_return("result")

      result = described_class.call("value")

      expect(result).to eq("result")
    end
  end

  describe "#call" do
    it "raises UndefinedCallError with descriptive message" do
      expect { validator.call("value") }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Validator"
      )
    end
  end

  describe "subclass implementation" do
    let(:working_validator_class) do
      Class.new(described_class) do
        def call(value, options = {})
          min_length = options[:min_length] || 0
          raise CMDx::ValidationError, "too short" if value.length < min_length

          "validated_#{value}"
        end
      end
    end

    let(:broken_validator_class) do
      Class.new(described_class) do
        # Intentionally doesn't implement call method
      end
    end

    it "works when subclass properly implements call method" do
      result = working_validator_class.call("test", min_length: 3)

      expect(result).to eq("validated_test")
    end

    it "raises validation error when subclass validation fails" do
      expect { working_validator_class.call("hi", min_length: 5) }.to raise_error(
        CMDx::ValidationError,
        "too short"
      )
    end

    it "raises error when subclass doesn't implement call method" do
      expect { broken_validator_class.call("test") }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_task_class(name: "SimpleValidationTask") do
        required :input, type: :string, presence: {}

        def call
          context.processed_input = input
        end
      end
    end

    it "works with built-in validations in task parameters" do
      result = task_class.call(input: "valid_input")

      expect(result).to be_successful_task
      expect(result.context.processed_input).to eq("valid_input")
    end

    it "fails when validation is violated" do
      result = task_class.call(input: "")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("cannot be empty")
    end

    it "fails when required parameter with validation is missing" do
      result = task_class.call({})

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("is a required parameter")
    end

    it "works with multiple validations on same parameter" do
      task_class = create_task_class(name: "MultiValidationTask") do
        required :email, type: :string, presence: {}, format: { with: /@/ }

        def call
          context.validated_email = email
        end
      end

      result = task_class.call(email: "user@example.com")

      expect(result).to be_successful_task
      expect(result.context.validated_email).to eq("user@example.com")
    end

    it "fails when one of multiple validations is violated" do
      task_class = create_task_class(name: "MultiValidationTask") do
        required :email, type: :string, presence: {}, format: { with: /@/ }

        def call
          context.validated_email = email
        end
      end

      result = task_class.call(email: "invalid_email")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("is an invalid format")
    end

    it "works with conditional validation using if option" do
      task_class = create_task_class(name: "ConditionalValidationTask") do
        required :input, type: :string, presence: { if: :should_validate? }

        def call
          context.processed_input = input
        end

        private

        def should_validate?
          context.validation_enabled == true
        end
      end

      result = task_class.call(input: "", validation_enabled: false)

      expect(result).to be_successful_task
      expect(result.context.processed_input).to eq("")
    end

    it "fails with conditional validation when condition is met" do
      task_class = create_task_class(name: "ConditionalValidationTask") do
        required :input, type: :string, presence: { if: :should_validate? }

        def call
          context.processed_input = input
        end

        private

        def should_validate?
          context.validation_enabled == true
        end
      end

      result = task_class.call(input: "", validation_enabled: true)

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("cannot be empty")
    end

    it "skips validation for nil values when allow_nil is true" do
      task_class = create_task_class(name: "AllowNilTask") do
        optional :input, type: :string, presence: { allow_nil: true }

        def call
          context.processed_input = input
        end
      end

      result = task_class.call(input: nil)

      expect(result).to be_successful_task
      expect(result.context.processed_input).to eq("") # String coercion converts nil to ""
    end
  end
end
