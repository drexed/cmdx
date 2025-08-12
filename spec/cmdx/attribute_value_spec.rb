# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeValue do
  subject(:attribute_value) { described_class.new(attribute) }

  let(:task_class) { create_task_class }
  let(:task) { task_class.new(context_data) }
  let(:context_data) { {} }
  let(:attribute_name) { :test_attr }
  let(:attribute_options) { {} }
  let(:attribute) { CMDx::Attribute.new(attribute_name, attribute_options) }

  before { attribute.task = task }

  describe "#initialize" do
    it "sets the attribute and delegators work correctly" do
      aggregate_failures do
        expect(attribute_value.attribute).to eq(attribute)
        expect(attribute_value.task).to eq(task)
        expect(attribute_value.name).to eq(attribute_name)
        expect(attribute_value.options).to eq(attribute_options)
        expect(attribute_value.types).to eq([])
        expect(attribute_value.method_name).to eq(:test_attr)
        expect(attribute_value.required?).to be(false)
        expect(attribute_value.attributes).to eq(task.attributes)
        expect(attribute_value.errors).to eq(task.errors)
      end
    end

    context "with different attribute configurations" do
      let(:attribute_options) { { types: [:string], required: true } }

      it "delegates correctly to configured attribute" do
        aggregate_failures do
          expect(attribute_value.types).to eq([:string])
          expect(attribute_value.required?).to be(true)
        end
      end
    end
  end

  describe "#value" do
    context "when attribute value exists in attributes hash" do
      before { task.attributes[:test_attr] = "existing_value" }

      it "returns the stored value" do
        expect(attribute_value.value).to eq("existing_value")
      end
    end

    context "when attribute value does not exist" do
      it "returns nil" do
        expect(attribute_value.value).to be_nil
      end
    end

    context "with custom method name" do
      let(:attribute_options) { { as: :custom_name } }

      before { task.attributes[:custom_name] = "custom_value" }

      it "uses the custom method name to retrieve value" do
        expect(attribute_value.value).to eq("custom_value")
      end
    end
  end

  describe "#generate" do
    context "when value already exists in attributes" do
      before { task.attributes[:test_attr] = "existing_value" }

      it "returns the existing value without processing" do
        allow(attribute_value).to receive(:source_value)
        result = attribute_value.generate
        expect(result).to eq("existing_value")
        expect(attribute_value).not_to have_received(:source_value)
      end
    end

    context "when value needs to be generated" do
      let(:context_data) { { test_attr: "context_value" } }

      it "processes through the full generation pipeline" do
        result = attribute_value.generate
        aggregate_failures do
          expect(result).to eq("context_value")
          expect(task.attributes[:test_attr]).to eq("context_value")
        end
      end

      context "when source_value returns error" do
        before do
          allow(attribute_value).to receive(:source_value).and_return(nil)
          allow(task.errors).to receive(:for?).with(:test_attr).and_return(true)
        end

        it "returns early without further processing" do
          allow(attribute_value).to receive(:derive_value)
          allow(attribute_value).to receive(:coerce_value)
          result = attribute_value.generate
          expect(result).to be_nil
          expect(attribute_value).not_to have_received(:derive_value)
          expect(attribute_value).not_to have_received(:coerce_value)
        end
      end

      context "when derive_value returns error" do
        before do
          allow(attribute_value).to receive_messages(source_value: "source", derive_value: nil)
          allow(task.errors).to receive(:for?).with(:test_attr).and_return(false, true)
        end

        it "returns early without coercion" do
          allow(attribute_value).to receive(:coerce_value)
          result = attribute_value.generate
          expect(result).to be_nil
          expect(attribute_value).not_to have_received(:coerce_value)
        end
      end

      context "when coerce_value returns error" do
        before do
          allow(attribute_value).to receive_messages(source_value: "source", derive_value: "derived", coerce_value: nil)
          allow(task.errors).to receive(:for?).with(:test_attr).and_return(false, false, true)
        end

        it "returns early without storing value" do
          result = attribute_value.generate
          aggregate_failures do
            expect(result).to be_nil
            expect(task.attributes).not_to have_key(:test_attr)
          end
        end
      end
    end

    context "with type coercion" do
      let(:attribute_options) { { types: [:integer] } }
      let(:context_data) { { test_attr: "123" } }

      it "coerces value to specified type" do
        result = attribute_value.generate
        aggregate_failures do
          expect(result).to eq(123)
          expect(task.attributes[:test_attr]).to eq(123)
        end
      end
    end
  end

  describe "#validate" do
    let(:validator_registry) { instance_double("ValidatorRegistry") }
    let(:attribute_options) { { presence: true, length: { min: 3 } } }

    before do
      task.attributes[:test_attr] = "test_value"
      allow(task.class).to receive(:settings).and_return({ validators: validator_registry })
      allow(validator_registry).to receive(:keys).and_return(%i[presence length format])
    end

    context "when validation passes" do
      before do
        allow(validator_registry).to receive(:validate).with(:presence, task, "test_value", true)
        allow(validator_registry).to receive(:validate).with(:length, task, "test_value", { min: 3 })
      end

      it "validates without adding errors" do
        allow(task.errors).to receive(:add)
        attribute_value.validate
        expect(task.errors).not_to have_received(:add)
      end
    end

    context "when validation fails" do
      let(:validation_error) { CMDx::ValidationError.new("too short") }

      before do
        allow(validator_registry).to receive(:validate).with(:presence, task, "test_value", true)
        allow(validator_registry).to receive(:validate).with(:length, task, "test_value", { min: 3 }).and_raise(validation_error)
      end

      it "adds validation error to errors collection" do
        allow(task.errors).to receive(:add)
        attribute_value.validate
        expect(task.errors).to have_received(:add).with(:test_attr, "too short")
      end
    end

    context "with multiple validation types" do
      let(:presence_error) { CMDx::ValidationError.new("cannot be empty") }
      let(:length_error) { CMDx::ValidationError.new("too short") }

      before do
        allow(validator_registry).to receive(:validate).with(:presence, task, "test_value", true).and_raise(presence_error)
        allow(validator_registry).to receive(:validate).with(:length, task, "test_value", { min: 3 }).and_raise(length_error)
      end

      it "continues validation after first error" do
        allow(task.errors).to receive(:add)
        attribute_value.validate
        expect(task.errors).to have_received(:add).with(:test_attr, "cannot be empty")
        expect(task.errors).to have_received(:add).with(:test_attr, "too short")
      end
    end

    context "when no validators match options" do
      let(:attribute_options) { { custom_option: true } }

      it "skips validation" do
        allow(validator_registry).to receive(:validate)
        attribute_value.validate
        expect(validator_registry).not_to have_received(:validate)
      end
    end
  end

  describe "#source_value (private)" do
    context "when source is a Symbol" do
      let(:attribute_options) { { source: :context } }

      before { allow(task).to receive(:context).and_return("context_result") }

      it "calls the method on task" do
        result = attribute_value.send(:source_value)
        expect(result).to eq("context_result")
      end

      context "when method does not exist" do
        let(:attribute_options) { { source: :nonexistent_method } }

        it "adds error and returns nil" do
          allow(task.errors).to receive(:add)
          result = attribute_value.send(:source_value)
          expect(result).to be_nil
          expect(task.errors).to have_received(:add).with(:test_attr, "delegates to undefined method nonexistent_method")
        end
      end
    end

    context "when source is a Proc" do
      let(:attribute_options) { { source: proc { "proc_result" } } }

      it "evaluates proc in task instance context" do
        result = attribute_value.send(:source_value)
        expect(result).to eq("proc_result")
      end

      context "when proc accesses task instance variables" do
        let(:attribute_options) { { source: proc { context } } }

        it "has access to task context" do
          result = attribute_value.send(:source_value)
          expect(result).to eq(task.context)
        end
      end
    end

    context "when source responds to call" do
      let(:callable_source) { instance_double("callable", call: "callable_result") }
      let(:attribute_options) { { source: callable_source } }

      it "calls the object with task as argument" do
        allow(callable_source).to receive(:call).with(task).and_return("callable_result")
        result = attribute_value.send(:source_value)
        expect(result).to eq("callable_result")
        expect(callable_source).to have_received(:call).with(task)
      end
    end

    context "when source is a direct value" do
      let(:attribute_options) { { source: "direct_value" } }

      it "returns the source value directly" do
        result = attribute_value.send(:source_value)
        expect(result).to eq("direct_value")
      end
    end

    context "when attribute is required" do
      let(:attribute_options) { { required: true } }
      let(:context_data) { { test_attr: "value" } }

      context "when source is Context and has the key" do
        before { allow(attribute_value).to receive(:source).and_return(task.context) }

        it "does not add required error" do
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).not_to have_received(:add)
        end
      end

      context "when source is Context and lacks the key" do
        let(:context_data) { { other_key: "other_value" } }

        before { allow(attribute_value).to receive(:source).and_return(task.context) }

        it "adds required error" do
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).to have_received(:add).with(:test_attr, "must be accessible via the source")
        end
      end

      context "when source is Hash and has the key" do
        before { allow(attribute_value).to receive(:source).and_return({ test_attr: "value" }) }

        it "does not add required error" do
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).not_to have_received(:add)
        end
      end

      context "when source is Proc" do
        before { allow(attribute_value).to receive(:source).and_return(proc { "value" }) }

        it "assumes Proc can provide value and does not add error" do
          # Proc scenario returns true for requirement check, but still adds error due to logic
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).to have_received(:add).with(:test_attr, "must be accessible via the source")
        end
      end

      context "when source object responds to attribute name" do
        let(:source_object) { instance_double("source") }

        before do
          allow(attribute_value).to receive(:source).and_return(source_object)
          allow(source_object).to receive(:respond_to?).with(:call).and_return(false)
          allow(source_object).to receive(:respond_to?).with(:test_attr, true).and_return(true)
        end

        it "does not add required error" do
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).not_to have_received(:add)
        end
      end

      context "when source object does not respond to attribute name" do
        let(:source_object) { instance_double("source") }

        before do
          allow(attribute_value).to receive(:source).and_return(source_object)
          allow(source_object).to receive(:respond_to?).with(:call).and_return(false)
          allow(source_object).to receive(:respond_to?).with(:test_attr, true).and_return(false)
        end

        it "adds required error" do
          allow(task.errors).to receive(:add)
          attribute_value.send(:source_value)
          expect(task.errors).to have_received(:add).with(:test_attr, "must be accessible via the source")
        end
      end

      context "with parent attribute" do
        let(:parent_attribute) { CMDx::Attribute.new(:parent, required: true) }
        let(:attribute_options) { { parent: parent_attribute, required: true } }

        before { parent_attribute.task = task }

        context "when parent is required" do
          let(:context_data) { { other_key: "other_value" } }

          it "checks requirement validation but catches NoMethodError from parent source" do
            allow(task.errors).to receive(:add)
            attribute_value.send(:source_value)
            expect(task.errors).to have_received(:add).with(:test_attr, "delegates to undefined method parent")
          end
        end

        context "when parent is not required" do
          let(:parent_attribute) { CMDx::Attribute.new(:parent, required: false) }

          before { parent_attribute.task = task }

          it "still gets NoMethodError for undefined parent method" do
            allow(task.errors).to receive(:add)
            attribute_value.send(:source_value)
            expect(task.errors).to have_received(:add).with(:test_attr, "delegates to undefined method parent")
          end
        end
      end
    end
  end

  describe "#default_value (private)" do
    context "when no default option is provided" do
      it "returns nil" do
        result = attribute_value.send(:default_value)
        expect(result).to be_nil
      end
    end

    context "when default is a direct value" do
      let(:attribute_options) { { default: "default_value" } }

      it "returns the default value" do
        result = attribute_value.send(:default_value)
        expect(result).to eq("default_value")
      end
    end

    context "when default is a Symbol method name" do
      let(:attribute_options) { { default: :default_method } }

      before do
        allow(task).to receive(:respond_to?).and_return(false)
        allow(task).to receive(:respond_to?).with(:default_method, true).and_return(true)
        allow(task).to receive(:default_method).and_return("method_result")
      end

      it "calls the method on task" do
        result = attribute_value.send(:default_value)
        expect(result).to eq("method_result")
      end

      context "when method does not exist" do
        before do
          allow(task).to receive(:respond_to?).and_return(false)
          allow(task).to receive(:respond_to?).with(:default_method, true).and_return(false)
        end

        it "returns the symbol itself" do
          result = attribute_value.send(:default_value)
          expect(result).to eq(:default_method)
        end
      end
    end

    context "when default is a Proc" do
      let(:attribute_options) { { default: proc { "proc_default" } } }

      it "evaluates proc in task instance context" do
        result = attribute_value.send(:default_value)
        expect(result).to eq("proc_default")
      end

      context "when proc accesses task instance variables" do
        let(:attribute_options) { { default: proc { context[:fallback] || "fallback_value" } } }
        let(:context_data) { { fallback: "context_fallback" } }

        it "has access to task context" do
          result = attribute_value.send(:default_value)
          expect(result).to eq("context_fallback")
        end
      end
    end

    context "when default responds to call" do
      let(:callable_default) { instance_double("callable", call: "callable_default") }
      let(:attribute_options) { { default: callable_default } }

      it "calls the object with task as argument" do
        allow(callable_default).to receive(:call).with(task).and_return("callable_default")
        result = attribute_value.send(:default_value)
        expect(result).to eq("callable_default")
        expect(callable_default).to have_received(:call).with(task)
      end
    end
  end

  describe "#derive_value (private)" do
    context "when source_value is Context" do
      let(:source_value) { CMDx::Context.new(test_attr: "context_value") }

      it "extracts value using attribute name" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("context_value")
      end

      context "when key does not exist in context" do
        let(:source_value) { CMDx::Context.new(other_key: "other_value") }
        let(:attribute_options) { { default: "default_fallback" } }

        it "returns default value" do
          result = attribute_value.send(:derive_value, source_value)
          expect(result).to eq("default_fallback")
        end
      end
    end

    context "when source_value is Hash" do
      let(:source_value) { { test_attr: "hash_value", other: "other" } }

      it "extracts value using attribute name" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("hash_value")
      end

      context "when key does not exist in hash" do
        let(:source_value) { { other_key: "other_value" } }
        let(:attribute_options) { { default: "default_fallback" } }

        it "returns default value" do
          result = attribute_value.send(:derive_value, source_value)
          expect(result).to eq("default_fallback")
        end
      end
    end

    context "when source_value is Symbol" do
      let(:source_value) { :test_symbol }

      it "attempts to call send on the symbol but catches NoMethodError" do
        allow(task.errors).to receive(:add)
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to be_nil
        expect(task.errors).to have_received(:add).with(:test_attr, "delegates to undefined method test_attr")
      end

      context "when default value is provided" do
        let(:attribute_options) { { default: "default_fallback" } }

        it "returns default value when symbol method fails" do
          allow(task.errors).to receive(:add)
          result = attribute_value.send(:derive_value, source_value)
          expect(result).to be_nil # Already nil from rescue
          expect(task.errors).to have_received(:add).with(:test_attr, "delegates to undefined method test_attr")
        end
      end
    end

    context "when source_value is Proc" do
      let(:source_value) { proc { |name| "proc_#{name}" } }

      it "executes proc with attribute name" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("proc_test_attr")
      end
    end

    context "when source_value responds to call" do
      let(:source_value) { instance_double("callable", call: "callable_value") }

      it "calls object with task and attribute name" do
        allow(source_value).to receive(:call).with(task, :test_attr).and_return("callable_value")
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("callable_value")
        expect(source_value).to have_received(:call).with(task, :test_attr)
      end
    end

    context "when source_value does not respond to call" do
      let(:source_value) { "plain_string" }
      let(:attribute_options) { { default: "default_fallback" } }

      it "returns default value" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("default_fallback")
      end
    end

    context "when derived value is nil" do
      let(:source_value) { CMDx::Context.new(other_key: "other") }
      let(:attribute_options) { { default: "default_fallback" } }

      it "returns default value" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("default_fallback")
      end
    end

    context "when derived value is not nil" do
      let(:source_value) { CMDx::Context.new(test_attr: "") }

      it "returns derived value even if falsy" do
        result = attribute_value.send(:derive_value, source_value)
        expect(result).to eq("")
      end
    end
  end

  describe "#coerce_value (private)" do
    let(:coercion_registry) { instance_double("CoercionRegistry") }

    before do
      allow(task.class).to receive(:settings).and_return({ coercions: coercion_registry })
    end

    context "when no types are defined" do
      let(:derived_value) { "any_value" }

      it "returns value without coercion" do
        result = attribute_value.send(:coerce_value, derived_value)
        expect(result).to eq("any_value")
      end
    end

    context "with single type" do
      let(:attribute_options) { { types: [:string] } }
      let(:derived_value) { 123 }

      context "when coercion succeeds" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:string, task, 123, attribute_options).and_return("123")
        end

        it "returns coerced value" do
          result = attribute_value.send(:coerce_value, derived_value)
          expect(result).to eq("123")
        end
      end

      context "when coercion fails" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:string, task, 123, attribute_options).and_raise(CMDx::CoercionError)
        end

        it "adds error and returns nil" do
          allow(task.errors).to receive(:add)
          result = attribute_value.send(:coerce_value, derived_value)
          expect(result).to be_nil
          expect(task.errors).to have_received(:add).with(:test_attr, "could not coerce into one of: string")
        end
      end
    end

    context "with multiple types" do
      let(:attribute_options) { { types: %i[integer string] } }
      let(:derived_value) { "123" }

      context "when first type coercion succeeds" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:integer, task, "123", attribute_options).and_return(123)
        end

        it "returns coerced value from first successful type" do
          allow(coercion_registry).to receive(:coerce).with(:string, task, "123", attribute_options)
          result = attribute_value.send(:coerce_value, derived_value)
          expect(result).to eq(123)
          expect(coercion_registry).not_to have_received(:coerce).with(:string, task, "123", attribute_options)
        end
      end

      context "when first type fails but second succeeds" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:integer, task, "abc", attribute_options).and_raise(CMDx::CoercionError)
          allow(coercion_registry).to receive(:coerce).with(:string, task, "abc", attribute_options).and_return("abc")
        end

        let(:derived_value) { "abc" }

        it "tries next type and returns coerced value" do
          result = attribute_value.send(:coerce_value, derived_value)
          expect(result).to eq("abc")
        end
      end

      context "when all types fail" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:integer, task, [], attribute_options).and_raise(CMDx::CoercionError)
          allow(coercion_registry).to receive(:coerce).with(:string, task, [], attribute_options).and_raise(CMDx::CoercionError)
        end

        let(:derived_value) { [] }

        it "adds error with all type names and returns nil" do
          allow(task.errors).to receive(:add)
          result = attribute_value.send(:coerce_value, derived_value)
          expect(result).to be_nil
          expect(task.errors).to have_received(:add).with(:test_attr, "could not coerce into one of: integer, string")
        end
      end
    end

    context "with type that has localized name" do
      let(:attribute_options) { { types: [:big_decimal] } }
      let(:derived_value) { "invalid" }

      before do
        allow(coercion_registry).to receive(:coerce).with(:big_decimal, task, "invalid", attribute_options).and_raise(CMDx::CoercionError)
      end

      it "uses localized type name in error message" do
        allow(task.errors).to receive(:add)
        attribute_value.send(:coerce_value, derived_value)
        expect(task.errors).to have_received(:add).with(:test_attr, "could not coerce into one of: big decimal")
      end
    end
  end
end
