# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::ModuleExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  let(:test_class) { Class.new }
  let(:target_object) { double("target", test_method: "result", private_method: "private_result") }
  let(:instance) { test_class.new }

  before do
    allow(instance).to receive_messages(target: target_object, missing_target: nil)
  end

  describe "#cmdx_attr_delegator" do
    context "with basic delegation" do
      it "creates delegator method that forwards to target object" do
        test_class.cmdx_attr_delegator :test_method, to: :target

        expect(instance.test_method).to eq("result")
      end

      it "forwards arguments to delegated method" do
        test_class.cmdx_attr_delegator :test_method, to: :target

        instance.test_method("arg1", "arg2")

        expect(target_object).to have_received(:test_method).with("arg1", "arg2")
      end

      it "forwards keyword arguments to delegated method" do
        test_class.cmdx_attr_delegator :test_method, to: :target

        instance.test_method(key: "value")

        expect(target_object).to have_received(:test_method).with(key: "value")
      end

      it "forwards blocks to delegated method" do
        test_class.cmdx_attr_delegator :test_method, to: :target
        block = proc { "block_result" }

        instance.test_method(&block)

        expect(target_object).to have_received(:test_method).with(no_args) do |&passed_block|
          expect(passed_block).to eq(block)
        end
      end

      it "creates method with generated name using NameAffix utility" do
        allow(CMDx::Utils::NameAffix).to receive(:call).and_return(:custom_method_name)
        test_class.cmdx_attr_delegator :test_method, to: :target

        expect(CMDx::Utils::NameAffix).to have_received(:call).with(:test_method, :target, to: :target)
      end
    end

    context "with multiple methods" do
      it "creates delegator methods for all specified methods" do
        allow(target_object).to receive_messages(method_one: "one", method_two: "two")
        test_class.cmdx_attr_delegator :method_one, :method_two, to: :target

        expect(instance.method_one).to eq("one")
        expect(instance.method_two).to eq("two")
      end
    end

    context "with class delegation" do
      it "delegates to class when to option is :class" do
        allow(test_class).to receive(:class_method).and_return("class_result")
        test_class.cmdx_attr_delegator :class_method, to: :class

        expect(instance.class_method).to eq("class_result")
      end
    end

    context "with visibility options" do
      it "makes delegated method private when private option is true" do
        test_class.cmdx_attr_delegator :test_method, to: :target, private: true

        expect(test_class.private_instance_methods).to include(:test_method)
      end

      it "makes delegated method protected when protected option is true" do
        test_class.cmdx_attr_delegator :test_method, to: :target, protected: true

        expect(test_class.protected_instance_methods).to include(:test_method)
      end

      it "keeps delegated method public by default" do
        test_class.cmdx_attr_delegator :test_method, to: :target

        expect(test_class.public_instance_methods).to include(:test_method)
      end
    end

    context "with allow_missing option" do
      it "does not raise error when method missing and allow_missing is true" do
        allow(target_object).to receive(:respond_to?).with(:missing_method, true).and_return(false)
        allow(target_object).to receive(:missing_method).and_return(nil)
        test_class.cmdx_attr_delegator :missing_method, to: :target, allow_missing: true

        expect { instance.missing_method }.not_to raise_error
      end

      it "raises NoMethodError when method missing and allow_missing is false" do
        allow(target_object).to receive(:respond_to?).with(:missing_method, true).and_return(false)
        test_class.cmdx_attr_delegator :missing_method, to: :target, allow_missing: false

        expect { instance.missing_method }.to raise_error(NoMethodError, /undefined method `missing_method' for target/)
      end

      it "raises NoMethodError when method missing and allow_missing not specified" do
        allow(target_object).to receive(:respond_to?).with(:missing_method, true).and_return(false)
        test_class.cmdx_attr_delegator :missing_method, to: :target

        expect { instance.missing_method }.to raise_error(NoMethodError, /undefined method `missing_method' for target/)
      end
    end

    context "with respond_to? checking" do
      it "checks if target responds to method with private methods included" do
        allow(target_object).to receive(:respond_to?).and_return(false)
        allow(target_object).to receive(:respond_to?).with(:test_method, true).and_return(true)
        test_class.cmdx_attr_delegator :test_method, to: :target

        instance.test_method

        expect(target_object).to have_received(:respond_to?).with(:test_method, true)
      end
    end
  end

  describe "#cmdx_attr_setting" do
    let(:parent_class) { Class.new }
    let(:child_class) { Class.new(parent_class) }

    context "with default values" do
      it "returns default value when no value is set" do
        test_class.cmdx_attr_setting :timeout, default: 30

        expect(test_class.timeout).to eq(30)
      end

      it "caches the default value for subsequent calls" do
        test_class.cmdx_attr_setting :timeout, default: 30

        first_call = test_class.timeout
        second_call = test_class.timeout

        expect(first_call).to eq(second_call)
        expect(first_call.object_id).to eq(second_call.object_id)
      end

      it "duplicates non-proc default values to prevent shared state" do
        default_hash = { key: "value" }
        test_class.cmdx_attr_setting :config, default: default_hash

        result = test_class.config

        expect(result).to eq(default_hash)
        expect(result.object_id).not_to eq(default_hash.object_id)
      end
    end

    context "with proc defaults" do
      it "executes proc to generate default value" do
        counter = 0
        test_class.cmdx_attr_setting :dynamic_value, default: -> { counter += 1 }

        expect(test_class.dynamic_value).to eq(1)
      end

      it "executes proc only once and caches result" do
        counter = 0
        test_class.cmdx_attr_setting :dynamic_value, default: -> { counter += 1 }

        first_call = test_class.dynamic_value
        second_call = test_class.dynamic_value

        expect(first_call).to eq(1)
        expect(second_call).to eq(1)
      end

      it "does not duplicate proc results" do
        test_class.cmdx_attr_setting :proc_result, default: -> { "result" }

        first_call = test_class.proc_result
        second_call = test_class.proc_result

        expect(first_call.object_id).to eq(second_call.object_id)
      end
    end

    context "with inheritance" do
      it "inherits value from superclass when not set in subclass" do
        parent_class.cmdx_attr_setting :inherited_value, default: "parent_value"
        allow(child_class).to receive(:superclass).and_return(parent_class)
        allow(parent_class).to receive(:cmdx_try).with(:inherited_value).and_return("parent_value")
        child_class.cmdx_attr_setting :inherited_value, default: "child_default"

        expect(child_class.inherited_value).to eq("parent_value")
      end

      it "duplicates inherited value to prevent shared state" do
        inherited_hash = { key: "value" }
        parent_class.cmdx_attr_setting :config, default: inherited_hash
        allow(child_class).to receive(:superclass).and_return(parent_class)
        allow(parent_class).to receive(:cmdx_try).with(:config).and_return(inherited_hash)
        child_class.cmdx_attr_setting :config, default: {}

        result = child_class.config

        expect(result).to eq(inherited_hash)
        expect(result.object_id).not_to eq(inherited_hash.object_id)
      end

      it "uses default when superclass returns nil" do
        allow(child_class).to receive(:superclass).and_return(parent_class)
        allow(parent_class).to receive(:cmdx_try).with(:missing_value).and_return(nil)
        child_class.cmdx_attr_setting :missing_value, default: "default_value"

        expect(child_class.missing_value).to eq("default_value")
      end
    end

    context "with cmdx_invoke integration" do
      it "calls cmdx_invoke on default value" do
        callable_default = double("callable")
        allow(callable_default).to receive(:cmdx_invoke).and_return("called_result")
        allow(callable_default).to receive(:is_a?).with(Proc).and_return(false)
        test_class.cmdx_attr_setting :callable_value, default: callable_default

        expect(test_class.callable_value).to eq("called_result")
      end
    end

    context "with facets storage" do
      it "initializes @cmd_facets hash when first accessed" do
        test_class.cmdx_attr_setting :first_value, default: "value"

        test_class.first_value

        expect(test_class.instance_variable_get(:@cmd_facets)).to be_a(Hash)
      end

      it "stores values in @cmd_facets hash with method name as key" do
        test_class.cmdx_attr_setting :stored_value, default: "value"

        test_class.stored_value

        expect(test_class.instance_variable_get(:@cmd_facets)[:stored_value]).to eq("value")
      end

      it "returns cached value from @cmd_facets when key exists" do
        test_class.cmdx_attr_setting :cached_value, default: "original"
        test_class.instance_variable_set(:@cmd_facets, { cached_value: "cached" })

        expect(test_class.cached_value).to eq("cached")
      end
    end
  end

  describe "Module inclusion" do
    it "extends Module class with ModuleExtensions" do
      expect(Module.ancestors).to include(described_class)
    end

    it "makes cmdx_attr_delegator available on all modules" do
      new_module = Module.new

      expect(new_module).to respond_to(:cmdx_attr_delegator)
    end

    it "makes cmdx_attr_setting available on all modules" do
      new_module = Module.new

      expect(new_module).to respond_to(:cmdx_attr_setting)
    end
  end
end
