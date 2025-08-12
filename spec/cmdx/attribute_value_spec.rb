# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeValue do
  let(:task_class) { create_task_class }
  let(:errors) { instance_double(CMDx::Errors, add: nil, for?: false) }
  let(:task) { task_class.new }
  let(:attribute) { CMDx::Attribute.new(:test_attr, **attribute_options) }
  let(:attribute_options) { {} }
  let(:attribute_value) { described_class.new(attribute) }

  before do
    attribute.task = task
    allow(task).to receive_messages(attributes: {}, errors: errors)
  end

  describe "#initialize" do
    it "sets the attribute" do
      expect(attribute_value.attribute).to eq(attribute)
    end
  end

  describe "#value" do
    let(:method_name) { :test_method }

    before do
      allow(attribute_value).to receive(:method_name).and_return(method_name)
      allow(task).to receive(:attributes).and_return({ method_name => "test_value" })
    end

    it "returns value from attributes hash" do
      expect(attribute_value.value).to eq("test_value")
    end
  end

  describe "#generate" do
    let(:method_name) { :test_method }
    let(:attributes) { {} }

    before do
      allow(attribute_value).to receive(:method_name).and_return(method_name)
      allow(task).to receive(:attributes).and_return(attributes)
    end

    context "when value already exists in attributes" do
      let(:attributes) { { method_name => "existing_value" } }

      it "returns existing value" do
        expect(attribute_value.generate).to eq("existing_value")
      end

      it "does not call source_value" do
        expect(attribute_value).not_to receive(:source_value)
        attribute_value.generate
      end
    end

    context "when value does not exist" do
      before do
        allow(attribute_value).to receive_messages(
          source_value: "sourced",
          derive_value: "derived",
          coerce_value: "coerced"
        )
      end

      it "processes value through pipeline and stores result" do
        allow(attribute_value).to receive(:source_value).and_return("sourced")
        allow(attribute_value).to receive(:derive_value).with("sourced").and_return("derived")
        allow(attribute_value).to receive(:coerce_value).with("derived").and_return("coerced")

        expect { attribute_value.generate }.to change { attributes[method_name] }.to("coerced")
      end

      context "when errors occur after source_value" do
        before { allow(errors).to receive(:for?).with(method_name).and_return(true) }

        it "returns nil without processing further" do
          allow(attribute_value).to receive(:source_value).and_return("sourced")

          expect(attribute_value).not_to receive(:derive_value)

          expect(attribute_value.generate).to be_nil
        end
      end

      context "when errors occur after derive_value" do
        before do
          allow(errors).to receive(:for?).with(method_name).and_return(false, true)
          allow(attribute_value).to receive(:derive_value).and_return("derived")
        end

        it "returns nil without coercing" do
          allow(attribute_value).to receive(:source_value).and_return("sourced")
          allow(attribute_value).to receive(:derive_value).with("sourced").and_return("derived")

          expect(attribute_value).not_to receive(:coerce_value)

          expect(attribute_value.generate).to be_nil
        end
      end

      context "when errors occur after coerce_value" do
        before do
          allow(errors).to receive(:for?).with(method_name).and_return(false, false, true)
          allow(attribute_value).to receive(:coerce_value).and_return("coerced")
        end

        it "returns nil without storing value" do
          allow(attribute_value).to receive(:source_value).and_return("sourced")
          allow(attribute_value).to receive(:derive_value).with("sourced").and_return("derived")
          allow(attribute_value).to receive(:coerce_value).with("derived").and_return("coerced")

          result = attribute_value.generate

          expect(result).to be_nil
          expect(attributes).not_to have_key(method_name)
        end
      end
    end
  end

  describe "#validate" do
    let(:method_name) { :test_method }
    let(:validator_registry) { instance_double(CMDx::ValidatorRegistry) }
    let(:task_settings) { { validators: validator_registry } }
    let(:attribute_options) { { format: /\d+/, presence: true } }

    before do
      allow(attribute_value).to receive_messages(method_name: method_name, value: "test_value")
      allow(task.class).to receive(:settings).and_return(task_settings)
      allow(validator_registry).to receive(:keys).and_return(%i[format presence])
      allow(validator_registry).to receive(:validate)
    end

    it "validates each matching validator option" do
      expect(validator_registry).to receive(:validate).with(:format, task, "test_value", /\d+/)
      expect(validator_registry).to receive(:validate).with(:presence, task, "test_value", true)

      expect { attribute_value.validate }.not_to raise_error
    end

    context "when validation fails" do
      let(:validation_error) { CMDx::ValidationError.new("invalid format") }

      before do
        allow(validator_registry).to receive(:validate).and_raise(validation_error)
      end

      it "adds error message" do
        expect(errors).to receive(:add).with(method_name, "invalid format").twice

        attribute_value.validate
      end
    end

    context "when options don't match registry keys" do
      let(:attribute_options) { { unknown_option: true } }

      it "does not validate unknown options" do
        expect(validator_registry).not_to receive(:validate)

        expect { attribute_value.validate }.not_to raise_error
      end
    end
  end

  describe "private methods" do
    describe "#source_value" do
      let(:source) { :context }
      let(:method_name) { :test_method }

      before do
        allow(attribute_value).to receive_messages(
          source: source,
          method_name: method_name,
          required?: false
        )
      end

      context "when source is a symbol" do
        let(:source) { :config }

        before { allow(task).to receive(:config).and_return("config_value") }

        it "calls method on task" do
          allow(task).to receive(:config).and_return("config_value")

          expect(attribute_value.send(:source_value)).to eq("config_value")
        end
      end

      context "when source is a proc" do
        let(:source) { proc { "proc_result" } }

        before { allow(task).to receive(:instance_eval).and_return("proc_result") }

        it "evaluates proc in task context" do
          allow(task).to receive(:instance_eval).and_return("proc_result")

          expect(attribute_value.send(:source_value)).to eq("proc_result")
        end
      end

      context "when source is callable" do
        let(:callable) { instance_double("MockCallable", call: "callable_result") }
        let(:source) { callable }

        before { allow(source).to receive(:respond_to?).with(:call).and_return(true) }

        it "calls object with task" do
          allow(source).to receive(:call).with(task).and_return("callable_result")

          expect(attribute_value.send(:source_value)).to eq("callable_result")
        end
      end

      context "when source is not callable" do
        let(:source) { "string_value" }

        it "returns source directly" do
          expect(attribute_value.send(:source_value)).to eq("string_value")
        end
      end

      context "when source method raises NoMethodError" do
        let(:source) { :nonexistent_method }

        before do
          allow(task).to receive(:nonexistent_method).and_raise(NoMethodError)
          allow(CMDx::Locale).to receive(:t).with("cmdx.attributes.undefined", method: source).and_return("undefined method error")
        end

        it "adds error and returns nil" do
          expect(errors).to receive(:add).with(method_name, "undefined method error")

          expect(attribute_value.send(:source_value)).to be_nil
        end
      end

      context "when attribute is required" do
        let(:name) { :test_name }

        before do
          allow(attribute_value).to receive_messages(
            required?: true,
            parent: nil,
            name: name
          )
        end

        context "with Context source" do
          let(:context) { CMDx::Context.new(test_name: "value") }
          let(:source) { context }

          before { allow(source).to receive(:respond_to?).with(:call).and_return(false) }

          it "checks if context has key" do
            expect(attribute_value.send(:source_value)).to eq(context)
          end

          context "when context missing key" do
            let(:context) { CMDx::Context.new({}) }

            before do
              allow(CMDx::Locale).to receive(:t).with("cmdx.attributes.required").and_return("required error")
            end

            it "adds required error" do
              expect(errors).to receive(:add).with(method_name, "required error")

              expect(attribute_value.send(:source_value)).to eq(context)
            end
          end
        end

        context "with Hash source" do
          let(:source) { { test_name: "value" } }

          before { allow(source).to receive(:respond_to?).with(:call).and_return(false) }

          it "checks if hash has key" do
            expect(attribute_value.send(:source_value)).to eq(source)
          end
        end

        context "with Proc source" do
          let(:source) { proc { "value" } }

          before { allow(task).to receive(:instance_eval).and_return("value") }

          it "assumes proc can provide value" do
            expect(attribute_value.send(:source_value)).to eq("value")
          end
        end

        context "with object that responds to method" do
          let(:source_object) { instance_double("MockSource", test_name: "value") }
          let(:source) { source_object }

          before do
            allow(source).to receive(:respond_to?).with(:call).and_return(false)
            allow(source).to receive(:respond_to?).with(name, true).and_return(true)
          end

          it "checks if object responds to method" do
            expect(attribute_value.send(:source_value)).to eq(source_object)
          end
        end

        context "when parent is required" do
          let(:parent) { instance_double(CMDx::Attribute, required?: true) }

          before { allow(attribute_value).to receive(:parent).and_return(parent) }

          context "when source doesn't provide value" do
            let(:source_object) { instance_double("MockSource") }
            let(:source) { source_object }

            before do
              allow(source).to receive(:respond_to?).with(:call).and_return(false)
              allow(source).to receive(:respond_to?).with(name, true).and_return(false)
              allow(CMDx::Locale).to receive(:t).with("cmdx.attributes.required").and_return("required error")
            end

            it "adds required error" do
              expect(errors).to receive(:add).with(method_name, "required error")

              expect(attribute_value.send(:source_value)).to eq(source_object)
            end
          end
        end
      end
    end

    describe "#default_value" do
      let(:attribute_options) { { default: default_option } }
      let(:default_option) { "default_string" }

      context "when default is a string" do
        it "returns the string" do
          expect(attribute_value.send(:default_value)).to eq("default_string")
        end
      end

      context "when default is a symbol and task responds to it" do
        let(:default_option) { :default_method }

        before do
          allow(task).to receive(:respond_to?).with(:default_method, true).and_return(true)
          allow(task).to receive(:respond_to?).with(:default_method).and_return(true)
          allow(task).to receive(:default_method).and_return("method_result")
        end

        it "calls method on task" do
          allow(task).to receive(:default_method).and_return("method_result")

          expect(attribute_value.send(:default_value)).to eq("method_result")
        end
      end

      context "when default is a symbol but task doesn't respond" do
        let(:default_option) { :nonexistent_method }

        before { allow(task).to receive(:respond_to?).with(:nonexistent_method, true).and_return(false) }

        it "returns the symbol" do
          expect(attribute_value.send(:default_value)).to eq(:nonexistent_method)
        end
      end

      context "when default is a proc" do
        let(:default_option) { proc { "proc_default" } }

        before { allow(task).to receive(:instance_eval).and_return("proc_default") }

        it "evaluates proc in task context" do
          allow(task).to receive(:instance_eval).and_return("proc_default")

          expect(attribute_value.send(:default_value)).to eq("proc_default")
        end
      end

      context "when default is callable" do
        let(:callable) { instance_double("MockCallable", call: "callable_default") }
        let(:default_option) { callable }

        before { allow(default_option).to receive(:respond_to?).with(:call).and_return(true) }

        it "calls object with task" do
          allow(default_option).to receive(:call).with(task).and_return("callable_default")

          expect(attribute_value.send(:default_value)).to eq("callable_default")
        end
      end

      context "when no default option" do
        let(:attribute_options) { {} }

        it "returns nil" do
          expect(attribute_value.send(:default_value)).to be_nil
        end
      end
    end

    describe "#derive_value" do
      let(:name) { :test_name }
      let(:method_name) { :test_method }

      before do
        allow(attribute_value).to receive_messages(
          name: name,
          method_name: method_name,
          default_value: "default"
        )
      end

      context "when source_value is Context" do
        let(:context) { CMDx::Context.new(test_name: "context_value") }

        it "extracts value using name key" do
          expect(attribute_value.send(:derive_value, context)).to eq("context_value")
        end

        context "when context doesn't have key" do
          let(:context) { CMDx::Context.new({}) }

          it "returns default value" do
            expect(attribute_value.send(:derive_value, context)).to eq("default")
          end
        end
      end

      context "when source_value is Hash" do
        let(:hash) { { test_name: "hash_value" } }

        it "extracts value using name key" do
          expect(attribute_value.send(:derive_value, hash)).to eq("hash_value")
        end
      end

      context "when source_value is not Context, Hash, or Proc" do
        let(:source_object) { instance_double("MockSource", test_name: "object_value") }

        before { allow(source_object).to receive(:respond_to?).with(:call).and_return(false) }

        it "returns default value" do
          expect(attribute_value.send(:derive_value, source_object)).to eq("default")
        end

        context "when method raises NoMethodError" do
          let(:source_object) { instance_double("MockSource") }

          before do
            allow(source_object).to receive(:respond_to?).with(:call).and_return(false)
            allow(CMDx::Locale).to receive(:t).with("cmdx.attributes.undefined", method: name).and_return("undefined error")
          end

          it "adds error and returns nil" do
            expect(attribute_value.send(:derive_value, source_object)).to eq("default")
          end
        end
      end

      context "when source_value is Proc" do
        let(:proc_obj) { proc { |n| "proc_#{n}" } }

        before { allow(task).to receive(:instance_exec).with(name, &proc_obj).and_return("proc_test_name") }

        it "executes proc with name in task context" do
          allow(task).to receive(:instance_exec).with(name, &proc_obj).and_return("proc_test_name")

          expect(attribute_value.send(:derive_value, proc_obj)).to eq("proc_test_name")
        end
      end

      context "when source_value is callable" do
        let(:callable) { instance_double("MockCallable", call: "callable_value") }

        before { allow(callable).to receive(:respond_to?).with(:call).and_return(true) }

        it "calls object with task and name" do
          allow(callable).to receive(:call).with(task, name).and_return("callable_value")

          expect(attribute_value.send(:derive_value, callable)).to eq("callable_value")
        end
      end

      context "when source_value is not callable" do
        it "returns default value" do
          expect(attribute_value.send(:derive_value, "not_callable")).to eq("default")
        end
      end

      context "when derived_value is nil" do
        let(:hash) { { other_key: "value" } }

        it "returns default value" do
          expect(attribute_value.send(:derive_value, hash)).to eq("default")
        end
      end
    end

    describe "#coerce_value" do
      let(:method_name) { :test_method }
      let(:coercion_registry) { instance_double(CMDx::CoercionRegistry) }
      let(:task_settings) { { coercions: coercion_registry } }
      let(:types) { %i[string integer] }

      before do
        allow(attribute_value).to receive(:method_name).and_return(method_name)
        allow(attribute).to receive(:types).and_return(types)
        allow(task.class).to receive(:settings).and_return(task_settings)
      end

      context "when attribute has no types" do
        let(:types) { [] }

        it "returns value unchanged" do
          expect(attribute_value.send(:coerce_value, "unchanged")).to eq("unchanged")
        end
      end

      context "when coercion succeeds on first type" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:string, task, "123", {}).and_return("coerced_string")
        end

        it "returns coerced value" do
          expect(attribute_value.send(:coerce_value, "123")).to eq("coerced_string")
        end
      end

      context "when first coercion fails but second succeeds" do
        before do
          allow(coercion_registry).to receive(:coerce).with(:string, task, "123", {}).and_raise(CMDx::CoercionError)
          allow(coercion_registry).to receive(:coerce).with(:integer, task, "123", {}).and_return(123)
        end

        it "returns coerced value from successful type" do
          expect(attribute_value.send(:coerce_value, "123")).to eq(123)
        end
      end

      context "when all coercions fail" do
        before do
          allow(coercion_registry).to receive(:coerce).and_raise(CMDx::CoercionError)
          allow(CMDx::Locale).to receive(:t).with("cmdx.types.string").and_return("String")
          allow(CMDx::Locale).to receive(:t).with("cmdx.types.integer").and_return("Integer")
          allow(CMDx::Locale).to receive(:t).with("cmdx.coercions.into_any", types: "String, Integer").and_return("coercion error")
        end

        it "adds error and returns nil" do
          expect(errors).to receive(:add).with(method_name, "coercion error")

          expect(attribute_value.send(:coerce_value, "invalid")).to be_nil
        end
      end

      context "when coercion fails on intermediate type" do
        let(:types) { %i[string integer float] }

        before do
          allow(coercion_registry).to receive(:coerce).with(:string, task, "123", {}).and_raise(CMDx::CoercionError)
          allow(coercion_registry).to receive(:coerce).with(:integer, task, "123", {}).and_raise(CMDx::CoercionError)
          allow(coercion_registry).to receive(:coerce).with(:float, task, "123", {}).and_return(123.0)
        end

        it "continues to next type and succeeds" do
          expect(attribute_value.send(:coerce_value, "123")).to eq(123.0)
        end
      end
    end
  end
end
