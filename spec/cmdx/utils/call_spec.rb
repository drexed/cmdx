# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Call, type: :unit do
  subject(:call_module) { described_class }

  let(:target_object) do
    Class.new do
      def test_method(*args, **kwargs, &block)
        result = { args: args, kwargs: kwargs }
        result[:block_result] = yield if block
        result
      end

      def no_args_method
        "no_args_result"
      end

      def method_with_return_value(value)
        "returned_#{value}"
      end

      def method_with_side_effect
        @side_effect_called = true
        "side_effect_result"
      end

      def side_effect_called?
        @side_effect_called == true
      end
    end.new
  end

  describe ".invoke" do
    context "when callable is a Symbol" do
      it "calls the method on target with no arguments" do
        result = call_module.invoke(target_object, :no_args_method)

        expect(result).to eq("no_args_result")
      end

      it "calls the method on target with positional arguments" do
        result = call_module.invoke(target_object, :test_method, "arg1", "arg2")

        expect(result).to eq({
          args: %w[arg1 arg2],
          kwargs: {}
        })
      end

      it "calls the method on target with keyword arguments" do
        result = call_module.invoke(target_object, :test_method, key1: "value1", key2: "value2")

        expect(result).to eq({
          args: [],
          kwargs: { key1: "value1", key2: "value2" }
        })
      end

      it "calls the method on target with both positional and keyword arguments" do
        result = call_module.invoke(target_object, :test_method, "arg1", key: "value")

        expect(result).to eq({
          args: ["arg1"],
          kwargs: { key: "value" }
        })
      end

      it "calls the method on target with a block" do
        result = call_module.invoke(target_object, :test_method) { "block_result" }

        expect(result).to eq({
          args: [],
          kwargs: {},
          block_result: "block_result"
        })
      end

      it "calls the method on target with arguments and block" do
        result = call_module.invoke(target_object, :test_method, "arg1", key: "value") { "block_result" }

        expect(result).to eq({
          args: ["arg1"],
          kwargs: { key: "value" },
          block_result: "block_result"
        })
      end

      it "returns the method's return value" do
        result = call_module.invoke(target_object, :method_with_return_value, "test")

        expect(result).to eq("returned_test")
      end

      it "executes method with side effects" do
        expect(target_object.side_effect_called?).to be(false)

        call_module.invoke(target_object, :method_with_side_effect)

        expect(target_object.side_effect_called?).to be(true)
      end
    end

    context "when callable is a Proc" do
      it "executes proc in target context with no arguments" do
        proc_callable = proc { no_args_method }

        result = call_module.invoke(target_object, proc_callable)

        expect(result).to eq("no_args_result")
      end

      it "executes proc in target context with positional arguments" do
        proc_callable = proc { |arg1, arg2| test_method(arg1, arg2) }

        result = call_module.invoke(target_object, proc_callable, "arg1", "arg2")

        expect(result).to eq({
          args: %w[arg1 arg2],
          kwargs: {}
        })
      end

      it "executes proc in target context with keyword arguments" do
        proc_callable = proc { |key1:, key2:| test_method(key1: key1, key2: key2) }

        result = call_module.invoke(target_object, proc_callable, key1: "value1", key2: "value2")

        expect(result).to eq({
          args: [],
          kwargs: { key1: "value1", key2: "value2" }
        })
      end

      it "executes proc in target context with mixed arguments" do
        proc_callable = proc { |arg, key:| test_method(arg, key: key) }

        result = call_module.invoke(target_object, proc_callable, "arg1", key: "value")

        expect(result).to eq({
          args: ["arg1"],
          kwargs: { key: "value" }
        })
      end

      it "executes proc with access to target instance variables" do
        proc_callable = proc do
          @test_var = "set_by_proc"
          @test_var # rubocop:disable RSpec/InstanceVariable
        end

        result = call_module.invoke(target_object, proc_callable)

        expect(result).to eq("set_by_proc")
        expect(target_object.instance_variable_get(:@test_var)).to eq("set_by_proc")
      end

      it "executes proc with access to target methods" do
        proc_callable = proc { method_with_return_value("from_proc") }

        result = call_module.invoke(target_object, proc_callable)

        expect(result).to eq("returned_from_proc")
      end

      it "executes proc with block" do
        proc_callable = proc { test_method { "block_result" } }

        result = call_module.invoke(target_object, proc_callable)

        expect(result).to eq({
          args: [],
          kwargs: {},
          block_result: "block_result"
        })
      end

      it "executes proc that modifies target state" do
        proc_callable = proc { method_with_side_effect }

        expect(target_object.side_effect_called?).to be(false)

        call_module.invoke(target_object, proc_callable)

        expect(target_object.side_effect_called?).to be(true)
      end

      it "handles proc that returns nil" do
        proc_callable = proc {}

        result = call_module.invoke(target_object, proc_callable)

        expect(result).to be_nil
      end

      it "handles proc that raises an exception" do
        proc_callable = proc { raise StandardError, "proc error" }

        expect do
          call_module.invoke(target_object, proc_callable)
        end.to raise_error(StandardError, "proc error")
      end
    end

    context "when callable responds to :call" do
      let(:callable_object) do
        Class.new do
          def call(*args, **kwargs, &block)
            result = { args: args, kwargs: kwargs }
            result[:block_result] = yield if block
            result
          end
        end.new
      end

      it "calls the callable object with no arguments" do
        result = call_module.invoke(target_object, callable_object)

        expect(result).to eq({
          args: [],
          kwargs: {}
        })
      end

      it "calls the callable object with positional arguments" do
        result = call_module.invoke(target_object, callable_object, "arg1", "arg2")

        expect(result).to eq({
          args: %w[arg1 arg2],
          kwargs: {}
        })
      end

      it "calls the callable object with keyword arguments" do
        result = call_module.invoke(target_object, callable_object, key1: "value1", key2: "value2")

        expect(result).to eq({
          args: [],
          kwargs: { key1: "value1", key2: "value2" }
        })
      end

      it "calls the callable object with mixed arguments" do
        result = call_module.invoke(target_object, callable_object, "arg1", key: "value")

        expect(result).to eq({
          args: ["arg1"],
          kwargs: { key: "value" }
        })
      end

      it "calls the callable object with a block" do
        result = call_module.invoke(target_object, callable_object) { "block_result" }

        expect(result).to eq({
          args: [],
          kwargs: {},
          block_result: "block_result"
        })
      end

      it "returns the callable object's return value" do
        return_value_callable = Class.new do
          def call
            "callable_result"
          end
        end.new

        result = call_module.invoke(target_object, return_value_callable)

        expect(result).to eq("callable_result")
      end

      it "handles callable that returns nil" do
        nil_callable = Class.new do
          def call
            nil
          end
        end.new

        result = call_module.invoke(target_object, nil_callable)

        expect(result).to be_nil
      end

      it "handles callable that raises an exception" do
        error_callable = Class.new do
          def call
            raise StandardError, "callable error"
          end
        end.new

        expect do
          call_module.invoke(target_object, error_callable)
        end.to raise_error(StandardError, "callable error")
      end
    end

    context "when callable is lambda" do
      it "executes lambda in target context" do
        lambda_callable = -> { no_args_method }

        result = call_module.invoke(target_object, lambda_callable)

        expect(result).to eq("no_args_result")
      end

      it "executes lambda with strict argument checking" do
        lambda_callable = ->(arg) { method_with_return_value(arg) }

        result = call_module.invoke(target_object, lambda_callable, "test")

        expect(result).to eq("returned_test")
      end

      it "raises error when lambda argument count doesn't match" do
        lambda_callable = ->(arg) { method_with_return_value(arg) }

        expect do
          call_module.invoke(target_object, lambda_callable)
        end.to raise_error(ArgumentError)
      end
    end

    context "when callable is invalid" do
      it "raises error for string" do
        expect do
          call_module.invoke(target_object, "invalid_string")
        end.to raise_error(/cannot invoke invalid_string/)
      end

      it "raises error for integer" do
        expect do
          call_module.invoke(target_object, 42)
        end.to raise_error(/cannot invoke 42/)
      end

      it "raises error for array" do
        expect do
          call_module.invoke(target_object, [1, 2, 3])
        end.to raise_error(/cannot invoke \[1, 2, 3\]/)
      end

      it "raises error for hash" do
        expect do
          call_module.invoke(target_object, { key: "value" })
        end.to raise_error(/cannot invoke {key: "value"}/)
      end

      it "raises error for nil" do
        expect do
          call_module.invoke(target_object, nil)
        end.to raise_error(/cannot invoke /)
      end

      it "raises error for object that doesn't respond to call" do
        non_callable = Class.new.new

        expect do
          call_module.invoke(target_object, non_callable)
        end.to raise_error(/cannot invoke/)
      end
    end

    context "when target raises NoMethodError for symbol callable" do
      it "raises NoMethodError for undefined method" do
        expect do
          call_module.invoke(target_object, :undefined_method)
        end.to raise_error(NoMethodError)
      end
    end

    context "with edge cases" do
      it "handles empty symbol" do
        empty_symbol = :""

        expect do
          call_module.invoke(target_object, empty_symbol)
        end.to raise_error(NoMethodError)
      end

      it "handles proc with default parameters" do
        proc_with_defaults = proc { |arg = "default"| method_with_return_value(arg) }

        result = call_module.invoke(target_object, proc_with_defaults)

        expect(result).to eq("returned_default")
      end

      it "handles proc with variable arguments" do
        proc_with_splat = proc { |*args| test_method(*args) }

        result = call_module.invoke(target_object, proc_with_splat, "arg1", "arg2", "arg3")

        expect(result).to eq({
          args: %w[arg1 arg2 arg3],
          kwargs: {}
        })
      end

      it "handles callable with variable arguments" do
        splat_callable = Class.new do
          def call(*args, **kwargs)
            { received_args: args, received_kwargs: kwargs }
          end
        end.new

        result = call_module.invoke(target_object, splat_callable, "a", "b", x: 1, y: 2)

        expect(result).to eq({
          received_args: %w[a b],
          received_kwargs: { x: 1, y: 2 }
        })
      end
    end
  end
end
