# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Condition do
  subject(:condition_module) { described_class }

  let(:target_object) do
    Class.new do
      def true_method?
        true
      end

      def false_method?
        false
      end

      def method_with_args(arg)
        arg
      end

      def method_with_kwargs(value:)
        value
      end

      def method_with_block(&)
        yield
      end
    end.new
  end

  describe ".evaluate" do
    context "when options contain if: condition" do
      context "when if condition is true" do
        it "returns true for true boolean" do
          result = condition_module.evaluate(target_object, { if: true })
          expect(result).to be true
        end

        it "returns true for truthy symbol method" do
          result = condition_module.evaluate(target_object, { if: :true_method? })
          expect(result).to be true
        end

        it "returns true for truthy proc" do
          proc = -> { true }
          result = condition_module.evaluate(target_object, { if: proc })
          expect(result).to be true
        end

        it "passes arguments to symbol method" do
          allow(target_object).to receive(:method_with_args).and_return(true)

          condition_module.evaluate(target_object, { if: :method_with_args }, "arg1")

          expect(target_object).to have_received(:method_with_args).with("arg1")
        end

        it "passes keyword arguments to symbol method" do
          allow(target_object).to receive(:method_with_kwargs).and_return(true)

          condition_module.evaluate(target_object, { if: :method_with_kwargs }, value: "test")

          expect(target_object).to have_received(:method_with_kwargs).with(value: "test")
        end

        it "passes block to symbol method" do
          allow(target_object).to receive(:method_with_block).and_return(true)
          test_block = -> { "block_result" }

          condition_module.evaluate(target_object, { if: :method_with_block }, &test_block)

          expect(target_object).to have_received(:method_with_block)
        end
      end

      context "when if condition is false" do
        it "returns false for false boolean" do
          result = condition_module.evaluate(target_object, { if: false })
          expect(result).to be false
        end

        it "returns false for nil" do
          result = condition_module.evaluate(target_object, { if: nil })
          expect(result).to be false
        end

        it "returns false for falsy symbol method" do
          result = condition_module.evaluate(target_object, { if: :false_method? })
          expect(result).to be false
        end

        it "returns false for falsy proc" do
          proc = -> { false }
          result = condition_module.evaluate(target_object, { if: proc })
          expect(result).to be false
        end
      end

      context "with callable object" do
        it "returns truthy value when callable returns truthy value" do
          callable = instance_double("Callable")

          allow(callable).to receive(:respond_to?).with(:call).and_return(true)
          allow(callable).to receive(:call).and_return("truthy")

          result = condition_module.evaluate(target_object, { if: callable })

          expect(result).to eq("truthy")
        end

        it "returns falsy value when callable returns falsy value" do
          callable = instance_double("Callable")

          allow(callable).to receive(:respond_to?).with(:call).and_return(true)
          allow(callable).to receive(:call).and_return(false)

          result = condition_module.evaluate(target_object, { if: callable })

          expect(result).to be false
        end

        it "passes arguments to callable" do
          callable = instance_double("Callable")

          allow(callable).to receive(:respond_to?).with(:call).and_return(true)
          allow(callable).to receive(:call).and_return(true)

          condition_module.evaluate(target_object, { if: callable }, "arg1", key: "value")

          expect(callable).to have_received(:call).with("arg1", key: "value")
        end
      end

      context "with invalid callable" do
        it "raises error for non-callable object" do
          invalid_callable = "string"

          expect do
            condition_module.evaluate(target_object, { if: invalid_callable })
          end.to raise_error(/cannot evaluate "string"/)
        end
      end
    end

    context "when options contain unless: condition" do
      context "when unless condition is false" do
        it "returns true for false boolean" do
          result = condition_module.evaluate(target_object, { unless: false })

          expect(result).to be true
        end

        it "returns true for nil" do
          result = condition_module.evaluate(target_object, { unless: nil })

          expect(result).to be true
        end

        it "returns true for falsy symbol method" do
          result = condition_module.evaluate(target_object, { unless: :false_method? })

          expect(result).to be true
        end

        it "returns true for falsy proc" do
          proc = -> { false }
          result = condition_module.evaluate(target_object, { unless: proc })

          expect(result).to be true
        end
      end

      context "when unless condition is true" do
        it "returns false for true boolean" do
          result = condition_module.evaluate(target_object, { unless: true })

          expect(result).to be false
        end

        it "returns false for truthy symbol method" do
          result = condition_module.evaluate(target_object, { unless: :true_method? })

          expect(result).to be false
        end

        it "returns false for truthy proc" do
          proc = -> { true }
          result = condition_module.evaluate(target_object, { unless: proc })

          expect(result).to be false
        end
      end

      context "with callable object" do
        it "returns negated truthy value when callable returns truthy value" do
          callable = instance_double("Callable")

          allow(callable).to receive(:respond_to?).with(:call).and_return(true)
          allow(callable).to receive(:call).and_return("truthy")

          result = condition_module.evaluate(target_object, { unless: callable })

          expect(result).to be false
        end

        it "passes arguments to callable" do
          callable = instance_double("Callable")

          allow(callable).to receive(:respond_to?).with(:call).and_return(true)
          allow(callable).to receive(:call).and_return(false)

          condition_module.evaluate(target_object, { unless: callable }, "arg1", key: "value")

          expect(callable).to have_received(:call).with("arg1", key: "value")
        end
      end
    end

    context "when options contain both if: and unless: conditions" do
      it "returns true when if is true and unless is false" do
        result = condition_module.evaluate(target_object, { if: true, unless: false })

        expect(result).to be true
      end

      it "returns false when if is true and unless is true" do
        result = condition_module.evaluate(target_object, { if: true, unless: true })

        expect(result).to be false
      end

      it "returns false when if is false and unless is false" do
        result = condition_module.evaluate(target_object, { if: false, unless: false })

        expect(result).to be false
      end

      it "returns false when if is false and unless is true" do
        result = condition_module.evaluate(target_object, { if: false, unless: true })

        expect(result).to be false
      end

      it "evaluates both conditions with method calls" do
        result = condition_module.evaluate(target_object, { if: :true_method?, unless: :false_method? })

        expect(result).to be true
      end

      it "passes arguments to both conditions" do
        allow(target_object).to receive(:method_with_args).and_return(true, false)

        condition_module.evaluate(target_object, { if: :method_with_args, unless: :method_with_args }, "test")

        expect(target_object).to have_received(:method_with_args).with("test").twice
      end
    end

    context "when options are empty" do
      it "returns true for empty hash" do
        result = condition_module.evaluate(target_object, {})

        expect(result).to be true
      end

      it "returns true for hash with unrecognized keys" do
        result = condition_module.evaluate(target_object, { other_key: "value" })

        expect(result).to be true
      end
    end

    context "with proc conditions" do
      it "executes proc in target object context" do
        instance_var_proc = proc {
          @test_var = "set"
          true
        }

        condition_module.evaluate(target_object, { if: instance_var_proc })

        expect(target_object.instance_variable_get(:@test_var)).to eq("set")
      end

      it "passes arguments to proc in instance_exec context" do
        arg_capturing_proc = proc { |arg|
          @captured_arg = arg
          true
        }

        condition_module.evaluate(target_object, { if: arg_capturing_proc }, "test_arg")

        expect(target_object.instance_variable_get(:@captured_arg)).to eq("test_arg")
      end

      it "passes keyword arguments to proc" do
        kwarg_capturing_proc = proc { |value:|
          @captured_kwarg = value
          true
        }

        condition_module.evaluate(target_object, { if: kwarg_capturing_proc }, value: "test_value")

        expect(target_object.instance_variable_get(:@captured_kwarg)).to eq("test_value")
      end

      it "executes proc block method in target object context" do
        # Test that proc is executed in the context of the target object
        proc_that_uses_self = proc { respond_to?(:true_method?) }

        result = condition_module.evaluate(target_object, { if: proc_that_uses_self })

        expect(result).to be true
      end
    end
  end
end
