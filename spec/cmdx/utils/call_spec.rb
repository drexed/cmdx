# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Call do
  subject(:call_module) { described_class }

  let(:target_object) do
    instance_double("Target", test_method: "method_result", instance_variable_set: nil)
  end

  describe ".invoke" do
    context "when callable is a Symbol" do
      let(:callable) { :test_method }

      it "calls the method on the target object" do
        allow(target_object).to receive(:test_method)

        call_module.invoke(target_object, callable)

        expect(target_object).to have_received(:test_method).with(no_args)
      end

      it "passes arguments to the method" do
        args = %w[arg1 arg2]

        allow(target_object).to receive(:test_method)

        call_module.invoke(target_object, callable, *args)

        expect(target_object).to have_received(:test_method).with(*args)
      end

      it "passes keyword arguments to the method" do
        kwargs = { key1: "value1", key2: "value2" }

        allow(target_object).to receive(:test_method)

        call_module.invoke(target_object, callable, **kwargs)

        expect(target_object).to have_received(:test_method).with(**kwargs)
      end

      it "passes both arguments and keyword arguments to the method" do
        args = ["arg1"]
        kwargs = { key1: "value1" }

        allow(target_object).to receive(:test_method)

        call_module.invoke(target_object, callable, *args, **kwargs)

        expect(target_object).to have_received(:test_method).with(*args, **kwargs)
      end

      it "passes blocks to the method" do
        block = proc { "block_result" }

        allow(target_object).to receive(:test_method) do |&passed_block|
          expect(passed_block).to eq(block)
        end

        call_module.invoke(target_object, callable, &block)

        expect(target_object).to have_received(:test_method)
      end

      it "returns the result of the method call" do
        allow(target_object).to receive(:test_method).and_return("expected_result")

        result = call_module.invoke(target_object, callable)

        expect(result).to eq("expected_result")
      end
    end

    context "when callable is a Proc" do
      let(:callable) { proc { |*args, **kwargs| "proc_result_#{args.join('_')}_#{kwargs.values.join('_')}" } }

      it "executes the proc in the context of the target object" do
        allow(target_object).to receive(:instance_exec).with(no_args) do |&block|
          expect(block).to eq(callable)
          "instance_exec_result"
        end

        call_module.invoke(target_object, callable)

        expect(target_object).to have_received(:instance_exec).with(no_args)
      end

      it "passes arguments to instance_exec" do
        args = %w[arg1 arg2]

        allow(target_object).to receive(:instance_exec).with(*args, &callable)

        call_module.invoke(target_object, callable, *args)

        expect(target_object).to have_received(:instance_exec).with(*args, &callable)
      end

      it "passes keyword arguments to instance_exec" do
        kwargs = { key1: "value1", key2: "value2" }

        allow(target_object).to receive(:instance_exec).with(**kwargs, &callable)

        call_module.invoke(target_object, callable, **kwargs)

        expect(target_object).to have_received(:instance_exec).with(**kwargs, &callable)
      end

      it "passes both arguments and keyword arguments to instance_exec" do
        args = ["arg1"]
        kwargs = { key1: "value1" }

        allow(target_object).to receive(:instance_exec).with(*args, **kwargs, &callable)

        call_module.invoke(target_object, callable, *args, **kwargs)

        expect(target_object).to have_received(:instance_exec).with(*args, **kwargs, &callable)
      end

      it "passes blocks to instance_exec" do
        block = proc { "block_result" }

        allow(target_object).to receive(:instance_exec) do |&passed_block|
          expect(passed_block).to eq(callable)
        end

        call_module.invoke(target_object, callable, &block)

        expect(target_object).to have_received(:instance_exec)
      end

      it "returns the result of the proc execution" do
        allow(target_object).to receive(:instance_exec).and_return("proc_execution_result")

        result = call_module.invoke(target_object, callable)

        expect(result).to eq("proc_execution_result")
      end
    end

    context "when callable responds to call" do
      let(:callable) { instance_double("Callable", call: "callable_result") }

      before do
        allow(callable).to receive(:respond_to?).with(:call).and_return(true)
      end

      it "calls the call method on the callable object" do
        allow(callable).to receive(:call)

        call_module.invoke(target_object, callable)

        expect(callable).to have_received(:call).with(no_args)
      end

      it "passes arguments to the callable object" do
        args = %w[arg1 arg2]

        allow(callable).to receive(:call)

        call_module.invoke(target_object, callable, *args)

        expect(callable).to have_received(:call).with(*args)
      end

      it "passes keyword arguments to the callable object" do
        kwargs = { key1: "value1", key2: "value2" }

        allow(callable).to receive(:call)

        call_module.invoke(target_object, callable, **kwargs)

        expect(callable).to have_received(:call).with(**kwargs)
      end

      it "passes both arguments and keyword arguments to the callable object" do
        args = ["arg1"]
        kwargs = { key1: "value1" }

        allow(callable).to receive(:call)

        call_module.invoke(target_object, callable, *args, **kwargs)

        expect(callable).to have_received(:call).with(*args, **kwargs)
      end

      it "passes blocks to the callable object" do
        block = proc { "block_result" }

        allow(callable).to receive(:call) do |&passed_block|
          expect(passed_block).to eq(block)
        end

        call_module.invoke(target_object, callable, &block)

        expect(callable).to have_received(:call)
      end

      it "returns the result of the callable object call" do
        allow(callable).to receive(:call).and_return("callable_object_result")

        result = call_module.invoke(target_object, callable)

        expect(result).to eq("callable_object_result")
      end
    end

    context "when callable is a lambda" do
      let(:callable) { ->(arg) { "lambda_result_#{arg}" } }

      it "calls the lambda directly" do
        result = call_module.invoke(target_object, callable, "test")

        expect(result).to eq("lambda_result_test")
      end
    end

    context "when callable is a method object" do
      let(:method_owner) { Object.new.tap { |o| o.define_singleton_method(:test) { |arg| "method_result_#{arg}" } } }
      let(:callable) { method_owner.method(:test) }

      it "calls the method object" do
        result = call_module.invoke(target_object, callable, "test")

        expect(result).to eq("method_result_test")
      end
    end

    context "when callable is invalid" do
      let(:invalid_callable) { "not_callable" }

      it "raises an error with a descriptive message" do
        expect { call_module.invoke(target_object, invalid_callable) }
          .to raise_error(RuntimeError, "cannot invoke not_callable")
      end
    end

    context "when callable is nil" do
      let(:callable) { nil }

      it "raises an error" do
        expect { call_module.invoke(target_object, callable) }
          .to raise_error(RuntimeError, "cannot invoke ")
      end
    end

    context "when callable is an integer" do
      let(:callable) { 42 }

      it "raises an error" do
        expect { call_module.invoke(target_object, callable) }
          .to raise_error(RuntimeError, "cannot invoke 42")
      end
    end

    context "when callable responds to call but returns false" do
      let(:callable) { instance_double("NotCallable") }

      before do
        allow(callable).to receive(:respond_to?).with(:call).and_return(false)
      end

      it "raises an error" do
        expect { call_module.invoke(target_object, callable) }
          .to raise_error(RuntimeError, /cannot invoke/)
      end
    end
  end
end
