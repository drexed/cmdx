# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterValue do
  describe "#initialize" do
    context "when creating a parameter value processor" do
      let(:task) { mock_task }
      let(:parameter) { mock_parameter }

      it "stores the task instance" do
        processor = described_class.new(task, parameter)

        expect(processor.task).to eq(task)
      end

      it "stores the parameter definition" do
        processor = described_class.new(task, parameter)

        expect(processor.parameter).to eq(parameter)
      end
    end
  end

  describe "#call" do
    let(:task) { mock_task }
    let(:parameter) do
      mock_parameter(
        method_source: :context,
        name: :user_id,
        options: {},
        required?: true,
        optional?: false,
        type: :integer,
        parent: nil
      )
    end
    let(:context) { mock_context(user_id: "42") }
    let(:processor) { described_class.new(task, parameter) }

    before do
      allow(task).to receive(:respond_to?).with(:context, true).and_return(true)
      allow(task).to receive(:__cmdx_try).with(:context).and_return(context)
      allow(context).to receive(:__cmdx_respond_to?).with(:user_id, true).and_return(true)
      allow(context).to receive(:__cmdx_try).with(:user_id).and_return("42")
    end

    context "when processing a simple parameter" do
      it "returns the coerced and validated value" do
        result = processor.call

        expect(result).to eq(42)
      end
    end

    context "when parameter source is undefined" do
      before do
        allow(task).to receive(:respond_to?).with(:context, true).and_return(false)
        allow(task).to receive(:__cmdx_try).with(:context).and_return(nil)
      end

      it "raises ValidationError" do
        expect { processor.call }.to raise_error(CMDx::ValidationError, /delegates to undefined method/)
      end
    end

    context "when required parameter is missing" do
      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:user_id, true).and_return(false)
      end

      it "raises ValidationError" do
        expect { processor.call }.to raise_error(CMDx::ValidationError, /is a required parameter/)
      end
    end

    context "when parameter has default value" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :priority,
          options: { default: "normal" },
          required?: false,
          optional?: true,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:priority, true).and_return(false)
        allow(context).to receive(:__cmdx_try).with(:priority).and_return(nil)
        allow(task).to receive(:__cmdx_yield).with("normal").and_return("normal")
      end

      it "returns the default value" do
        result = processor.call

        expect(result).to eq("normal")
      end
    end

    context "when parameter has callable default value" do
      let(:default_proc) { -> { "calculated_default" } }
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :computed,
          options: { default: default_proc },
          required?: false,
          optional?: true,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:computed, true).and_return(false)
        allow(context).to receive(:__cmdx_try).with(:computed).and_return(nil)
        allow(task).to receive(:__cmdx_yield).with(default_proc).and_return("calculated_default")
      end

      it "evaluates the callable and returns the result" do
        result = processor.call

        expect(result).to eq("calculated_default")
      end
    end
  end

  describe "type coercion" do
    let(:task) { mock_task }
    let(:context) { mock_context }
    let(:processor) { described_class.new(task, parameter) }

    before do
      allow(task).to receive(:respond_to?).with(:context, true).and_return(true)
      allow(task).to receive(:__cmdx_try).with(:context).and_return(context)
      allow(context).to receive(:__cmdx_respond_to?).with(:value, true).and_return(true)
    end

    context "when coercing to integer" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :integer,
          parent: nil
        )
      end

      it "coerces string to integer" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("123")

        result = processor.call

        expect(result).to eq(123)
      end

      it "handles negative integers" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("-456")

        result = processor.call

        expect(result).to eq(-456)
      end

      it "raises CoercionError for invalid integer" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("invalid")

        expect { processor.call }.to raise_error(CMDx::CoercionError)
      end
    end

    context "when coercing to string" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "coerces integer to string" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return(42)

        result = processor.call

        expect(result).to eq("42")
      end

      it "keeps string as string" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("hello")

        result = processor.call

        expect(result).to eq("hello")
      end
    end

    context "when coercing to boolean" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :boolean,
          parent: nil
        )
      end

      it "coerces truthy values to true" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("true")

        result = processor.call

        expect(result).to be true
      end

      it "coerces falsy values to false" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("false")

        result = processor.call

        expect(result).to be false
      end
    end

    context "when coercing to float" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :float,
          parent: nil
        )
      end

      it "coerces string to float" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("3.14")

        result = processor.call

        expect(result).to eq(3.14)
      end

      it "coerces integer to float" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return(42)

        result = processor.call

        expect(result).to eq(42.0)
      end
    end

    context "when coercing to array" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :array,
          parent: nil
        )
      end

      it "keeps array as array" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return([1, 2, 3])

        result = processor.call

        expect(result).to eq([1, 2, 3])
      end

      it "wraps single value in array" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("single")

        result = processor.call

        expect(result).to eq(["single"])
      end
    end

    context "when coercing to hash" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :hash,
          parent: nil
        )
      end

      it "keeps hash as hash" do
        hash_value = { key: "value" }
        allow(context).to receive(:__cmdx_try).with(:value).and_return(hash_value)

        result = processor.call

        expect(result).to eq(hash_value)
      end
    end

    context "when coercing to virtual" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :virtual,
          parent: nil
        )
      end

      it "returns the source object directly" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("anything")

        result = processor.call

        expect(result).to eq("anything")
      end
    end

    context "when using multiple type fallbacks" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: %i[integer float],
          parent: nil
        )
      end

      it "tries first type successfully" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("123")

        result = processor.call

        expect(result).to eq(123)
      end

      it "falls back to second type when first fails" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("123.45")

        result = processor.call

        expect(result).to eq(123.45)
      end

      it "raises error when all types fail" do
        # Use a value that will fail both integer and float coercion
        allow(context).to receive(:__cmdx_try).with(:value).and_return("not-a-number")

        expect { processor.call }.to raise_error(CMDx::CoercionError, /could not coerce into one of/)
      end
    end

    context "when using unknown coercion type" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: {},
          required?: true,
          optional?: false,
          type: :unknown_type,
          parent: nil
        )
      end

      it "raises UnknownCoercionError" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("value")

        expect { processor.call }.to raise_error(CMDx::UnknownCoercionError, /unknown coercion unknown_type/)
      end
    end
  end

  describe "parameter validation" do
    let(:task) { mock_task }
    let(:context) { mock_context(value: "test") }
    let(:processor) { described_class.new(task, parameter) }

    before do
      allow(task).to receive(:respond_to?).with(:context, true).and_return(true)
      allow(task).to receive(:__cmdx_try).with(:context).and_return(context)
      allow(context).to receive(:__cmdx_respond_to?).with(:value, true).and_return(true)
      allow(context).to receive(:__cmdx_try).with(:value).and_return("test")
    end

    context "when validating presence" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { presence: true },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "passes validation for present value" do
        result = processor.call

        expect(result).to eq("test")
      end

      it "fails validation for empty value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when validating format" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { format: { with: /\Atest\z/ } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "passes validation for matching format" do
        result = processor.call

        expect(result).to eq("test")
      end

      it "fails validation for non-matching format" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("invalid")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when validating length" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { length: { min: 2, max: 10 } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "passes validation for valid length" do
        result = processor.call

        expect(result).to eq("test")
      end

      it "fails validation for too short value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("x")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end

      it "fails validation for too long value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("x" * 15)

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when validating inclusion" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { inclusion: { in: %w[red green blue] } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "passes validation for included value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("red")

        result = processor.call

        expect(result).to eq("red")
      end

      it "fails validation for excluded value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("yellow")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when validating exclusion" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { exclusion: { in: %w[forbidden banned] } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      it "passes validation for allowed value" do
        result = processor.call

        expect(result).to eq("test")
      end

      it "fails validation for forbidden value" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("forbidden")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when validating numeric constraints" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { numeric: { min: 0, max: 100 } },
          required?: true,
          optional?: false,
          type: :integer,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_try).with(:value).and_return(50)
      end

      it "passes validation for value within range" do
        result = processor.call

        expect(result).to eq(50)
      end

      it "fails validation for value below minimum" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return(-5)

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end

      it "fails validation for value above maximum" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return(150)

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end

    context "when using custom validation" do
      let(:custom_validator) { ->(value, _options) { value != "invalid" } }
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :value,
          options: { custom: { validator: custom_validator } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("test")
      end

      it "passes custom validation" do
        result = processor.call

        expect(result).to eq("test")
      end

      it "fails custom validation" do
        allow(context).to receive(:__cmdx_try).with(:value).and_return("invalid")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end
  end

  describe "optional parameter handling" do
    let(:task) { mock_task }
    let(:context) { mock_context }
    let(:processor) { described_class.new(task, parameter) }

    before do
      allow(task).to receive(:respond_to?).with(:context, true).and_return(true)
      allow(task).to receive(:__cmdx_try).with(:context).and_return(context)
    end

    context "when optional parameter is missing from source" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :optional_value,
          options: { presence: true },
          required?: false,
          optional?: true,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:optional_value, true).and_return(false)
        allow(context).to receive(:__cmdx_try).with(:optional_value).and_return(nil)
      end

      it "skips validation for missing optional parameter" do
        result = processor.call

        expect(result).to eq("")
      end
    end

    context "when optional parameter has allow_nil validation" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :nullable_value,
          options: { presence: { allow_nil: true } },
          required?: false,
          optional?: true,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:nullable_value, true).and_return(true)
        allow(context).to receive(:__cmdx_try).with(:nullable_value).and_return(nil)
      end

      it "skips validation when value is nil and allow_nil is true" do
        result = processor.call

        expect(result).to eq("")
      end
    end

    context "when parameter has conditional validation" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :conditional_value,
          options: { presence: { if: :should_validate? } },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:conditional_value, true).and_return(true)
        allow(context).to receive(:__cmdx_try).with(:conditional_value).and_return("")
        allow(task).to receive(:__cmdx_eval).with({ if: :should_validate? }).and_return(false)
      end

      it "skips validation when condition is false" do
        result = processor.call

        expect(result).to eq("")
      end
    end
  end

  describe "complex parameter scenarios" do
    let(:task) { mock_task }
    let(:context) { mock_context }
    let(:processor) { described_class.new(task, parameter) }

    before do
      allow(task).to receive(:respond_to?).with(:context, true).and_return(true)
      allow(task).to receive(:__cmdx_try).with(:context).and_return(context)
    end

    context "when parameter has nested parent" do
      let(:parent_parameter) { mock_parameter(optional?: false) }
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :nested_value,
          options: {},
          required?: true,
          optional?: false,
          type: :string,
          parent: parent_parameter
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:nested_value, true).and_return(true)
        allow(context).to receive(:__cmdx_try).with(:nested_value).and_return("nested")
      end

      it "processes nested parameter normally" do
        result = processor.call

        expect(result).to eq("nested")
      end
    end

    context "when source is nil and parent is optional" do
      let(:parent_parameter) { mock_parameter(optional?: true) }
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :child_value,
          options: {},
          required?: true,
          optional?: false,
          type: :string,
          parent: parent_parameter
        )
      end

      before do
        allow(task).to receive(:__cmdx_try).with(:context).and_return(nil)
      end

      it "processes parameter when parent is optional and source is nil" do
        result = processor.call

        expect(result).to eq("")
      end
    end

    context "when combining multiple validations" do
      let(:parameter) do
        mock_parameter(
          method_source: :context,
          name: :complex_value,
          options: {
            presence: true,
            length: { min: 3 },
            format: { with: /\A[a-z]+\z/ }
          },
          required?: true,
          optional?: false,
          type: :string,
          parent: nil
        )
      end

      before do
        allow(context).to receive(:__cmdx_respond_to?).with(:complex_value, true).and_return(true)
      end

      it "passes all validations for valid value" do
        allow(context).to receive(:__cmdx_try).with(:complex_value).and_return("hello")

        result = processor.call

        expect(result).to eq("hello")
      end

      it "fails when any validation fails" do
        allow(context).to receive(:__cmdx_try).with(:complex_value).and_return("Hi")

        expect { processor.call }.to raise_error(CMDx::ValidationError)
      end
    end
  end
end
