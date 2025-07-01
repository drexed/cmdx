# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middleware do
  let(:task) { double("Task") }
  let(:callable) { double("Callable") }

  describe "#call" do
    context "when called on base Middleware class" do
      subject(:middleware) { described_class.new }

      it "raises UndefinedCallError" do
        expect { middleware.call(task, callable) }.to raise_error(CMDx::UndefinedCallError, /call method not defined in CMDx::Middleware/)
      end
    end

    context "when subclass implements call method" do
      subject(:middleware) { custom_middleware_class.new }

      let(:custom_middleware_class) do
        Class.new(described_class) do
          def call(task, callable)
            callable.call(task)
          end
        end
      end

      it "executes the implemented call method" do
        expect(callable).to receive(:call).with(task)

        middleware.call(task, callable)
      end

      it "returns the result from callable" do
        expected_result = double("Result")
        allow(callable).to receive(:call).with(task).and_return(expected_result)

        result = middleware.call(task, callable)

        expect(result).to eq(expected_result)
      end
    end

    context "when subclass modifies behavior before calling next middleware" do
      subject(:middleware) { logging_middleware_class.new }

      let(:logging_middleware_class) do
        Class.new(described_class) do
          attr_reader :logged_messages

          def initialize
            @logged_messages = []
          end

          def call(task, callable)
            @logged_messages << "Before execution"
            result = callable.call(task)
            @logged_messages << "After execution"
            result
          end
        end
      end

      it "executes custom logic before and after calling next middleware" do
        expected_result = double("Result")
        allow(callable).to receive(:call).with(task).and_return(expected_result)

        result = middleware.call(task, callable)

        expect(middleware.logged_messages).to eq(["Before execution", "After execution"])
        expect(result).to eq(expected_result)
      end
    end

    context "when subclass short-circuits execution" do
      subject(:middleware) { short_circuit_middleware_class.new }

      let(:short_circuit_middleware_class) do
        Class.new(described_class) do
          def call(task, callable)
            return "short-circuited" if task.should_skip?

            callable.call(task)
          end
        end
      end

      it "returns early without calling next middleware when condition is met" do
        allow(task).to receive(:should_skip?).and_return(true)
        allow(callable).to receive(:call)

        result = middleware.call(task, callable)

        expect(callable).not_to have_received(:call)
        expect(result).to eq("short-circuited")
      end

      it "calls next middleware when condition is not met" do
        expected_result = double("Result")
        allow(task).to receive(:should_skip?).and_return(false)
        allow(callable).to receive(:call).with(task).and_return(expected_result)

        result = middleware.call(task, callable)

        expect(callable).to have_received(:call).with(task)
        expect(result).to eq(expected_result)
      end
    end

    context "when subclass accepts initialization parameters" do
      let(:parameterized_middleware_class) do
        Class.new(described_class) do
          attr_reader :config

          def initialize(config = {})
            @config = config
          end

          def call(task, callable)
            if config[:enabled]
              callable.call(task)
            else
              "disabled"
            end
          end
        end
      end

      it "uses parameters to control behavior" do
        enabled_middleware = parameterized_middleware_class.new(enabled: true)
        expected_result = double("Result")
        allow(callable).to receive(:call).with(task).and_return(expected_result)

        result = enabled_middleware.call(task, callable)

        expect(result).to eq(expected_result)
      end

      it "can be disabled via parameters" do
        disabled_middleware = parameterized_middleware_class.new(enabled: false)
        allow(callable).to receive(:call)

        result = disabled_middleware.call(task, callable)

        expect(callable).not_to have_received(:call)
        expect(result).to eq("disabled")
      end
    end

    context "when subclass modifies task state" do
      subject(:middleware) { state_modifying_middleware_class.new }

      let(:state_modifying_middleware_class) do
        Class.new(described_class) do
          def call(task, callable)
            task.add_metadata("middleware_executed", true)
            callable.call(task)
          end
        end
      end

      it "modifies task state before calling next middleware" do
        expected_result = double("Result")
        allow(callable).to receive(:call).with(task).and_return(expected_result)
        allow(task).to receive(:add_metadata)

        result = middleware.call(task, callable)

        expect(task).to have_received(:add_metadata).with("middleware_executed", true)
        expect(result).to eq(expected_result)
      end
    end

    context "when subclass handles exceptions" do
      subject(:middleware) { exception_handling_middleware_class.new }

      let(:exception_handling_middleware_class) do
        Class.new(described_class) do
          def call(task, callable)
            callable.call(task)
          rescue StandardError => e
            "Error handled: #{e.message}"
          end
        end
      end

      it "catches and handles exceptions from next middleware" do
        allow(callable).to receive(:call).with(task).and_raise(StandardError, "Something went wrong")

        result = middleware.call(task, callable)

        expect(result).to eq("Error handled: Something went wrong")
      end

      it "returns normal result when no exception occurs" do
        expected_result = double("Result")
        allow(callable).to receive(:call).with(task).and_return(expected_result)

        result = middleware.call(task, callable)

        expect(result).to eq(expected_result)
      end
    end
  end

  describe "inheritance" do
    it "can be subclassed" do
      subclass = Class.new(described_class)

      expect(subclass.superclass).to eq(described_class)
    end

    it "allows multiple levels of inheritance" do
      base_middleware = Class.new(described_class)
      derived_middleware = Class.new(base_middleware)

      expect(derived_middleware.ancestors).to include(base_middleware, described_class)
    end
  end
end
