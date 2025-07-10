# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::ObjectExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  let(:test_object) { Object.new }
  let(:test_hash) { { name: "John", age: 30 } }
  let(:test_proc) { proc { "proc_result" } }
  let(:test_lambda) { -> { "lambda_result" } }

  describe "#cmdx_try" do
    context "with method calls" do
      it "calls method when object responds to it" do
        allow(test_object).to receive(:test_method).and_return("method_result")

        result = test_object.cmdx_try(:test_method)

        expect(result).to eq("method_result")
      end

      it "returns nil when object does not respond to method" do
        result = test_object.cmdx_try(:nonexistent_method)

        expect(result).to be_nil
      end

      it "forwards arguments to method call" do
        allow(test_object).to receive(:test_method).and_return("result")

        test_object.cmdx_try(:test_method, "arg1", "arg2")

        expect(test_object).to have_received(:test_method).with("arg1", "arg2")
      end

      it "forwards keyword arguments to method call" do
        allow(test_object).to receive(:test_method).and_return("result")

        test_object.cmdx_try(:test_method, key: "value")

        expect(test_object).to have_received(:test_method).with(key: "value")
      end

      it "checks respond_to? with private methods included" do
        allow(test_object).to receive(:respond_to?).and_return(false) # rubocop:disable RSpec/ReceiveMessages
        allow(test_object).to receive(:respond_to?).with(:test_method, true).and_return(true)
        allow(test_object).to receive(:test_method).and_return("result") # rubocop:disable RSpec/ReceiveMessages

        test_object.cmdx_try(:test_method)

        expect(test_object).to have_received(:respond_to?).with(:test_method, true)
      end
    end

    context "with proc execution" do
      it "executes proc when key is a Proc" do
        result = test_object.cmdx_try(test_proc)

        expect(result).to eq("proc_result")
      end

      it "executes lambda when key is a lambda" do
        result = test_object.cmdx_try(test_lambda)

        expect(result).to eq("lambda_result")
      end

      it "forwards arguments to proc call" do
        proc_with_args = ->(arg1, arg2) { "#{arg1}_#{arg2}" }

        result = test_object.cmdx_try(proc_with_args, "first", "second")

        expect(result).to eq("first_second")
      end

      it "uses instance_eval for procs when not Module and not lambda" do
        instance_proc = proc { self.class.name }

        result = test_object.cmdx_try(instance_proc)

        expect(result).to eq("Object")
      end

      it "calls proc directly for lambdas" do
        lambda_proc = -> { "direct_call" }

        result = test_object.cmdx_try(lambda_proc)

        expect(result).to eq("direct_call")
      end

      it "calls proc directly when object is a Module" do
        module_obj = Module.new
        module_proc = proc { "module_call" }

        result = module_obj.cmdx_try(module_proc)

        expect(result).to eq("module_call")
      end
    end

    context "with hash access" do
      it "accesses hash value using cmdx_fetch when object is Hash" do
        allow(test_hash).to receive(:cmdx_fetch).with(:name).and_return("John")

        result = test_hash.cmdx_try(:name)

        expect(result).to eq("John")
      end

      it "returns nil when hash key does not exist" do
        allow(test_hash).to receive(:cmdx_fetch).with(:missing).and_return(nil)

        result = test_hash.cmdx_try(:missing)

        expect(result).to be_nil
      end
    end

    context "with edge cases" do
      it "returns nil for non-proc, non-method, non-hash scenarios" do
        result = test_object.cmdx_try(:nonexistent)

        expect(result).to be_nil
      end
    end
  end

  describe "#cmdx_eval" do
    context "with if conditions" do
      it "returns true when if condition is truthy" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(true)

        result = test_object.cmdx_eval(if: :valid?)

        expect(result).to be true
      end

      it "returns false when if condition is falsy" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(false)

        result = test_object.cmdx_eval(if: :valid?)

        expect(result).to be false
      end

      it "evaluates proc conditions" do
        condition_proc = proc { true }
        allow(test_object).to receive(:cmdx_try).with(condition_proc).and_return(true)

        result = test_object.cmdx_eval(if: condition_proc)

        expect(result).to be true
      end
    end

    context "with unless conditions" do
      it "returns true when unless condition is falsy" do
        allow(test_object).to receive(:cmdx_try).with(:invalid?).and_return(false)

        result = test_object.cmdx_eval(unless: :invalid?)

        expect(result).to be true
      end

      it "returns false when unless condition is truthy" do
        allow(test_object).to receive(:cmdx_try).with(:invalid?).and_return(true)

        result = test_object.cmdx_eval(unless: :invalid?)

        expect(result).to be false
      end
    end

    context "with combined conditions" do
      it "returns true when if is true and unless is false" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(true)
        allow(test_object).to receive(:cmdx_try).with(:disabled?).and_return(false)

        result = test_object.cmdx_eval(if: :valid?, unless: :disabled?)

        expect(result).to be true
      end

      it "returns false when if is true but unless is also true" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(true)
        allow(test_object).to receive(:cmdx_try).with(:disabled?).and_return(true)

        result = test_object.cmdx_eval(if: :valid?, unless: :disabled?)

        expect(result).to be false
      end

      it "returns false when if is false regardless of unless" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(false)
        allow(test_object).to receive(:cmdx_try).with(:disabled?).and_return(false)

        result = test_object.cmdx_eval(if: :valid?, unless: :disabled?)

        expect(result).to be false
      end
    end

    context "with default behavior" do
      it "returns true when no conditions are provided" do
        result = test_object.cmdx_eval

        expect(result).to be true
      end

      it "returns default value when specified and no conditions" do
        result = test_object.cmdx_eval(default: false)

        expect(result).to be false
      end

      it "ignores default when conditions are present" do
        allow(test_object).to receive(:cmdx_try).with(:valid?).and_return(false)

        result = test_object.cmdx_eval(if: :valid?, default: true)

        expect(result).to be false
      end
    end
  end

  describe "#cmdx_yield" do
    context "with symbol and string keys" do
      it "calls method when object responds to symbol key" do
        allow(test_object).to receive(:respond_to?).and_return(false) # rubocop:disable RSpec/ReceiveMessages
        allow(test_object).to receive(:respond_to?).with(:test_method, true).and_return(true)
        allow(test_object).to receive(:test_method).and_return("method_result") # rubocop:disable RSpec/ReceiveMessages

        result = test_object.cmdx_yield(:test_method)

        expect(result).to eq("method_result")
      end

      it "returns symbol key when object does not respond to it" do
        allow(test_object).to receive(:respond_to?).with(:nonexistent, true).and_return(false)

        result = test_object.cmdx_yield(:nonexistent)

        expect(result).to eq(:nonexistent)
      end

      it "calls method when object responds to string key" do
        allow(test_object).to receive(:respond_to?).and_return(false) # rubocop:disable RSpec/ReceiveMessages
        allow(test_object).to receive(:respond_to?).with("test_method", true).and_return(true)
        allow(test_object).to receive(:test_method).and_return("method_result") # rubocop:disable RSpec/ReceiveMessages

        result = test_object.cmdx_yield("test_method")

        expect(result).to eq("method_result")
      end

      it "returns string key when object does not respond to it" do
        allow(test_object).to receive(:respond_to?).with("nonexistent", true).and_return(false)

        result = test_object.cmdx_yield("nonexistent")

        expect(result).to eq("nonexistent")
      end

      it "forwards arguments to method call" do
        allow(test_object).to receive(:respond_to?).and_return(false) # rubocop:disable RSpec/ReceiveMessages
        allow(test_object).to receive(:respond_to?).with(:test_method, true).and_return(true)
        allow(test_object).to receive(:test_method).and_return("result") # rubocop:disable RSpec/ReceiveMessages

        test_object.cmdx_yield(:test_method, "arg1", "arg2")

        expect(test_object).to have_received(:test_method).with("arg1", "arg2")
      end
    end

    context "with hash objects" do
      it "returns symbol when hash doesn't respond to it as method" do
        result = test_hash.cmdx_yield(:nonexistent_method)

        expect(result).to eq(:nonexistent_method)
      end
    end

    context "with proc keys" do
      it "calls cmdx_try when key is a Proc" do
        allow(test_object).to receive(:cmdx_try).with(test_proc).and_return("proc_result")

        result = test_object.cmdx_yield(test_proc)

        expect(result).to eq("proc_result")
      end
    end

    context "with direct values" do
      it "returns numeric values directly" do
        result = test_object.cmdx_yield(42)

        expect(result).to eq(42)
      end

      it "returns boolean values directly" do
        result = test_object.cmdx_yield(true)

        expect(result).to be true
      end

      it "returns nil directly" do
        result = test_object.cmdx_yield(nil)

        expect(result).to be_nil
      end

      it "returns array values directly" do
        array = [1, 2, 3]

        result = test_object.cmdx_yield(array)

        expect(result).to eq(array)
      end
    end
  end

  describe "#cmdx_call" do
    context "with callable objects" do
      it "calls object when it responds to call" do
        callable = proc { "called" }

        result = callable.cmdx_call

        expect(result).to eq("called")
      end

      it "forwards arguments to call method" do
        callable = proc { |arg| "called_#{arg}" }

        result = callable.cmdx_call("test")

        expect(result).to eq("called_test")
      end

      it "forwards keyword arguments to call method" do
        callable = proc { |key:| "called_#{key}" }

        result = callable.cmdx_call(key: "value")

        expect(result).to eq("called_value")
      end

      it "forwards blocks to call method" do
        callable = proc { |&block| block.call }
        block = proc { "block_result" }

        result = callable.cmdx_call(&block)

        expect(result).to eq("block_result")
      end
    end

    context "with non-callable objects" do
      it "returns self when object does not respond to call" do
        result = test_object.cmdx_call

        expect(result).to eq(test_object)
      end

      it "returns string unchanged" do
        string = "test_string"

        result = string.cmdx_call

        expect(result).to eq("test_string")
      end

      it "returns number unchanged" do
        number = 42

        result = number.cmdx_call

        expect(result).to eq(42)
      end
    end

    context "with respond_to? checking" do
      it "checks if object responds to call method" do
        allow(test_object).to receive(:respond_to?).with(:call).and_return(false)

        test_object.cmdx_call

        expect(test_object).to have_received(:respond_to?).with(:call)
      end
    end
  end

  describe "Object inclusion" do
    it "extends Object class with ObjectExtensions" do
      expect(Object.ancestors).to include(described_class)
    end

    it "makes cmdx_try available on all objects" do
      expect(test_object).to respond_to(:cmdx_try)
    end

    it "makes cmdx_eval available on all objects" do
      expect(test_object).to respond_to(:cmdx_eval)
    end

    it "makes cmdx_yield available on all objects" do
      expect(test_object).to respond_to(:cmdx_yield)
    end

    it "makes cmdx_call available on all objects" do
      expect(test_object).to respond_to(:cmdx_call)
    end

    it "preserves original respond_to? as cmdx_respond_to?" do
      expect(test_object).to respond_to(:cmdx_respond_to?)
    end
  end
end
