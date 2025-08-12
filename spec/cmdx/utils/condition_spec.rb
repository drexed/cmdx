# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Condition do
  subject(:condition_module) { described_class }

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

      def method_with_args(arg1, arg2)
        "#{arg1}_#{arg2}"
      end

      def method_with_kwargs(name:, value:)
        "#{name}: #{value}"
      end

      def truthy_method
        true
      end

      def falsy_method
        false
      end

      def instance_variable_check
        @instance_variable_check ||= "instance_value"
      end

      attr_accessor :accessible_value
    end.new
  end

  describe ".evaluate" do
    context "when options contain if condition" do
      context "with Symbol if condition" do
        it "returns true when if condition evaluates to truthy" do
          result = condition_module.evaluate(target_object, { if: :truthy_method })

          expect(result).to be(true)
        end

        it "returns false when if condition evaluates to falsy" do
          result = condition_module.evaluate(target_object, { if: :falsy_method })

          expect(result).to be(false)
        end

        it "passes arguments to the if condition method" do
          result = condition_module.evaluate(target_object, { if: :method_with_args }, "hello", "world")

          expect(result).to be_truthy
        end

        it "passes keyword arguments to the if condition method" do
          result = condition_module.evaluate(target_object, { if: :method_with_kwargs }, name: "test", value: "data")

          expect(result).to be_truthy
        end

        it "passes block to the if condition method" do
          allow(target_object).to receive(:test_method).and_return(true)

          condition_module.evaluate(target_object, { if: :test_method }) { "block_value" }

          expect(target_object).to have_received(:test_method)
        end
      end

      context "with Proc if condition" do
        it "returns true when Proc evaluates to truthy" do
          truthy_proc = proc { true }
          result = condition_module.evaluate(target_object, { if: truthy_proc })

          expect(result).to be(true)
        end

        it "returns false when Proc evaluates to falsy" do
          falsy_proc = proc { false }
          result = condition_module.evaluate(target_object, { if: falsy_proc })

          expect(result).to be(false)
        end

        it "executes Proc in the context of target object" do
          context_proc = proc { instance_variable_check }
          result = condition_module.evaluate(target_object, { if: context_proc })

          expect(result).to be_truthy
        end

        it "passes arguments to the Proc" do
          arg_proc = proc { |arg1, arg2| arg1 == "hello" && arg2 == "world" }
          result = condition_module.evaluate(target_object, { if: arg_proc }, "hello", "world")

          expect(result).to be(true)
        end

        it "passes keyword arguments to the Proc" do
          kwarg_proc = proc { |name:, value:| name == "test" && value == "data" }
          result = condition_module.evaluate(target_object, { if: kwarg_proc }, name: "test", value: "data")

          expect(result).to be(true)
        end
      end

      context "with callable object if condition" do
        let(:callable_object) do
          Class.new do
            def call(*_args, **_kwargs, &)
              true
            end
          end.new
        end

        let(:falsy_callable_object) do
          Class.new do
            def call(*_args, **_kwargs, &)
              false
            end
          end.new
        end

        it "returns true when callable returns truthy" do
          result = condition_module.evaluate(target_object, { if: callable_object })

          expect(result).to be(true)
        end

        it "returns false when callable returns falsy" do
          result = condition_module.evaluate(target_object, { if: falsy_callable_object })

          expect(result).to be(false)
        end

        it "passes arguments to the callable" do
          arg_callable = Class.new do
            def call(arg1, arg2)
              arg1 == "hello" && arg2 == "world"
            end
          end.new

          result = condition_module.evaluate(target_object, { if: arg_callable }, "hello", "world")

          expect(result).to be(true)
        end
      end

      context "with boolean if condition" do
        it "returns true when if condition is true" do
          result = condition_module.evaluate(target_object, { if: true })

          expect(result).to be(true)
        end

        it "returns false when if condition is false" do
          result = condition_module.evaluate(target_object, { if: false })

          expect(result).to be(false)
        end

        it "returns false when if condition is nil" do
          result = condition_module.evaluate(target_object, { if: nil })

          expect(result).to be(false)
        end
      end
    end

    context "when options contain unless condition" do
      context "with Symbol unless condition" do
        it "returns false when unless condition evaluates to truthy" do
          result = condition_module.evaluate(target_object, { unless: :truthy_method })

          expect(result).to be(false)
        end

        it "returns true when unless condition evaluates to falsy" do
          result = condition_module.evaluate(target_object, { unless: :falsy_method })

          expect(result).to be(true)
        end

        it "passes arguments to the unless condition method" do
          result = condition_module.evaluate(target_object, { unless: :method_with_args }, "hello", "world")

          expect(result).to be_falsy
        end
      end

      context "with Proc unless condition" do
        it "returns false when Proc evaluates to truthy" do
          truthy_proc = proc { true }
          result = condition_module.evaluate(target_object, { unless: truthy_proc })

          expect(result).to be(false)
        end

        it "returns true when Proc evaluates to falsy" do
          falsy_proc = proc { false }
          result = condition_module.evaluate(target_object, { unless: falsy_proc })

          expect(result).to be(true)
        end
      end

      context "with boolean unless condition" do
        it "returns false when unless condition is true" do
          result = condition_module.evaluate(target_object, { unless: true })

          expect(result).to be(false)
        end

        it "returns true when unless condition is false" do
          result = condition_module.evaluate(target_object, { unless: false })

          expect(result).to be(true)
        end

        it "returns true when unless condition is nil" do
          result = condition_module.evaluate(target_object, { unless: nil })

          expect(result).to be(true)
        end
      end
    end

    context "when options contain both if and unless conditions" do
      it "returns true when if is truthy and unless is falsy" do
        result = condition_module.evaluate(target_object, { if: :truthy_method, unless: :falsy_method })

        expect(result).to be(true)
      end

      it "returns false when if is truthy and unless is truthy" do
        result = condition_module.evaluate(target_object, { if: :truthy_method, unless: :truthy_method })

        expect(result).to be(false)
      end

      it "returns false when if is falsy and unless is falsy" do
        result = condition_module.evaluate(target_object, { if: :falsy_method, unless: :falsy_method })

        expect(result).to be(false)
      end

      it "returns false when if is falsy and unless is truthy" do
        result = condition_module.evaluate(target_object, { if: :falsy_method, unless: :truthy_method })

        expect(result).to be(false)
      end

      it "passes arguments to both conditions" do
        if_proc = proc { |arg| arg == "test" }
        unless_proc = proc { |arg| arg == "fail" }

        result = condition_module.evaluate(target_object, { if: if_proc, unless: unless_proc }, "test")

        expect(result).to be(true)
      end
    end

    context "when options contain neither if nor unless" do
      it "returns true for empty options" do
        result = condition_module.evaluate(target_object, {})

        expect(result).to be(true)
      end

      it "returns true for options with other keys" do
        result = condition_module.evaluate(target_object, { other_key: "value" })

        expect(result).to be(true)
      end
    end

    context "with invalid callable objects" do
      let(:invalid_callable) do
        Object.new
      end

      it "raises an error when if condition is not callable" do
        expect do
          condition_module.evaluate(target_object, { if: invalid_callable })
        end.to raise_error(RuntimeError, /cannot evaluate/)
      end

      it "raises an error when unless condition is not callable" do
        expect do
          condition_module.evaluate(target_object, { unless: invalid_callable })
        end.to raise_error(RuntimeError, /cannot evaluate/)
      end

      it "includes the invalid object in the error message" do
        expect do
          condition_module.evaluate(target_object, { if: invalid_callable })
        end.to raise_error(RuntimeError, /#{Regexp.escape(invalid_callable.inspect)}/)
      end
    end

    context "when target object doesn't respond to method" do
      it "raises NoMethodError for Symbol condition" do
        expect do
          condition_module.evaluate(target_object, { if: :nonexistent_method })
        end.to raise_error(NoMethodError)
      end
    end
  end

  describe "EVAL constant" do
    let(:eval_proc) { described_class.const_get(:EVAL) }

    context "when callable is NilClass" do
      it "returns false" do
        result = eval_proc.call(target_object, nil)

        expect(result).to be(false)
      end
    end

    context "when callable is FalseClass" do
      it "returns false" do
        result = eval_proc.call(target_object, false)

        expect(result).to be(false)
      end
    end

    context "when callable is TrueClass" do
      it "returns true" do
        result = eval_proc.call(target_object, true)

        expect(result).to be(true)
      end
    end

    context "when callable is Symbol" do
      it "calls the method on target" do
        result = eval_proc.call(target_object, :no_args_method)

        expect(result).to eq("no_args_result")
      end

      it "passes arguments to the method" do
        result = eval_proc.call(target_object, :method_with_args, "hello", "world")

        expect(result).to eq("hello_world")
      end

      it "passes keyword arguments to the method" do
        result = eval_proc.call(target_object, :method_with_kwargs, name: "test", value: "data")

        expect(result).to eq("test: data")
      end

      it "passes block to the method" do
        result = eval_proc.call(target_object, :test_method) { "block_value" }

        expect(result[:block_result]).to eq("block_value")
      end
    end

    context "when callable is Proc" do
      it "executes the Proc in target context" do
        test_proc = proc { instance_variable_check }
        result = eval_proc.call(target_object, test_proc)

        expect(result).to eq("instance_value")
      end

      it "passes arguments to the Proc" do
        arg_proc = proc { |arg1, arg2| "#{arg1}_#{arg2}" }
        result = eval_proc.call(target_object, arg_proc, "hello", "world")

        expect(result).to eq("hello_world")
      end

      it "passes keyword arguments to the Proc" do
        kwarg_proc = proc { |name:, value:| "#{name}: #{value}" }
        result = eval_proc.call(target_object, kwarg_proc, name: "test", value: "data")

        expect(result).to eq("test: data")
      end
    end

    context "when callable has call method" do
      let(:callable_object) do
        Class.new do
          def call(*args, **kwargs, &block)
            { args: args, kwargs: kwargs, block_called: block&.call }
          end
        end.new
      end

      it "calls the call method" do
        result = eval_proc.call(target_object, callable_object)

        expect(result).to eq({ args: [], kwargs: {}, block_called: nil })
      end

      it "passes arguments to the call method" do
        result = eval_proc.call(target_object, callable_object, "arg1", "arg2")

        expect(result).to eq({ args: %w[arg1 arg2], kwargs: {}, block_called: nil })
      end

      it "passes keyword arguments to the call method" do
        result = eval_proc.call(target_object, callable_object, name: "test", value: "data")

        expect(result).to eq({ args: [], kwargs: { name: "test", value: "data" }, block_called: nil })
      end

      it "passes block to the call method" do
        result = eval_proc.call(target_object, callable_object) { "block_value" }

        expect(result).to eq({ args: [], kwargs: {}, block_called: "block_value" })
      end
    end

    context "when callable doesn't respond to call" do
      let(:invalid_object) { Object.new }

      it "raises an error" do
        expect do
          eval_proc.call(target_object, invalid_object)
        end.to raise_error(RuntimeError, /cannot evaluate/)
      end

      it "includes the object in the error message" do
        expect do
          eval_proc.call(target_object, invalid_object)
        end.to raise_error(RuntimeError, /#{Regexp.escape(invalid_object.inspect)}/)
      end
    end
  end
end
