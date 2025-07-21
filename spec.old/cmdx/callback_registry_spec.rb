# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CallbackRegistry do
  subject(:registry) { described_class.new }

  let(:task) { create_simple_task(name: "TestTask").new }

  describe "TYPES constant" do
    it "includes all callback types" do
      expect(described_class::TYPES).to include(
        :before_validation,
        :after_validation,
        :before_execution,
        :after_execution,
        :on_executed,
        :on_good,
        :on_bad,
        :on_success,
        :on_skipped,
        :on_failed,
        :on_initialized,
        :on_executing,
        :on_complete,
        :on_interrupted
      )
    end

    it "is frozen" do
      expect(described_class::TYPES).to be_frozen
    end
  end

  describe ".new" do
    it "creates empty registry" do
      expect(registry.registry).to eq({})
    end

    it "accepts initial registry hash" do
      initial_registry = { before_execution: [[:method_name, {}]] }
      registry = described_class.new(initial_registry)

      expect(registry.registry).to eq(initial_registry)
    end

    it "converts initial registry to hash" do
      registry = described_class.new(nil)

      expect(registry.registry).to eq({})
    end
  end

  describe "#register" do
    it "registers single symbol callback" do
      registry.register(:before_execution, :setup_method)

      expect(registry.registry[:before_execution]).to eq([[[:setup_method], {}]])
    end

    it "registers multiple callbacks" do
      registry.register(:before_execution, :setup_method, :prepare_data)

      expect(registry.registry[:before_execution]).to eq([[%i[setup_method prepare_data], {}]])
    end

    it "registers callback with options" do
      condition = -> { true }
      registry.register(:on_good, :notify_success, if: condition)

      expect(registry.registry[:on_good]).to eq([[[:notify_success], { if: condition }]])
    end

    it "registers block callback" do
      block = -> { "callback" }
      registry.register(:after_execution, &block)

      expect(registry.registry[:after_execution]).to eq([[[block], {}]])
    end

    it "registers callback with both callables and block" do
      block = -> { "callback" }
      registry.register(:before_validation, :setup, &block)

      expect(registry.registry[:before_validation]).to eq([[[:setup, block], {}]])
    end

    it "returns self for method chaining" do
      result = registry.register(:before_execution, :setup)

      expect(result).to eq(registry)
    end

    it "maintains uniqueness of registrations" do
      registry.register(:before_execution, :setup)
      registry.register(:before_execution, :setup)

      expect(registry.registry[:before_execution]).to eq([[[:setup], {}]])
    end

    it "groups callbacks by type" do
      registry.register(:before_execution, :setup)
      registry.register(:after_execution, :cleanup)

      expect(registry.registry).to include(
        before_execution: [[[:setup], {}]],
        after_execution: [[[:cleanup], {}]]
      )
    end
  end

  describe "#call" do
    let(:executed_callbacks) { [] }
    let(:callback_task) do
      callbacks = executed_callbacks
      create_task_class(name: "CallbackTask") do
        define_method :setup_method do
          callbacks << :setup_method
        end

        define_method :cleanup_method do
          callbacks << :cleanup_method
        end

        define_method :conditional_method do
          callbacks << :conditional_method
        end

        define_method :call do
          context.executed = true
        end
      end.new
    end

    context "with valid callback types" do
      it "executes symbol callbacks" do
        registry.register(:before_execution, :setup_method)
        registry.call(callback_task, :before_execution)

        expect(executed_callbacks).to include(:setup_method)
      end

      it "executes string callbacks" do
        registry.register(:after_execution, "cleanup_method")
        registry.call(callback_task, :after_execution)

        expect(executed_callbacks).to include(:cleanup_method)
      end

      it "executes proc callbacks" do
        executed = false
        proc_callback = -> { executed = true }
        registry.register(:on_good, proc_callback)

        registry.call(callback_task, :on_good)

        expect(executed).to be true
      end

      it "executes callable object callbacks" do
        callable = double("Callable")
        expect(callable).to receive(:call).with(callback_task)

        registry.register(:on_executed, callable)
        registry.call(callback_task, :on_executed)
      end

      it "executes multiple callbacks in order" do
        registry.register(:before_execution, :setup_method, :cleanup_method)
        registry.call(callback_task, :before_execution)

        expect(executed_callbacks).to eq(%i[setup_method cleanup_method])
      end
    end

    context "with conditional execution" do
      it "executes callback when condition is true" do
        registry.register(:before_execution, :conditional_method, if: -> { true })
        registry.call(callback_task, :before_execution)

        expect(executed_callbacks).to include(:conditional_method)
      end

      it "skips callback when condition is false" do
        registry.register(:before_execution, :conditional_method, if: -> { false })
        registry.call(callback_task, :before_execution)

        expect(executed_callbacks).not_to include(:conditional_method)
      end

      it "evaluates conditions in task context" do
        task_with_flag = create_task_class do
          attr_accessor :should_execute

          def call
            context.executed = true
          end
        end.new

        task_with_flag.should_execute = true
        registry.register(:before_execution, :conditional_method, if: :should_execute)

        allow(task_with_flag).to receive(:conditional_method) { executed_callbacks << :conditional_method }

        registry.call(task_with_flag, :before_execution)

        expect(executed_callbacks).to include(:conditional_method)
      end
    end

    context "with empty registry" do
      it "does nothing for unregistered callback type" do
        expect { registry.call(callback_task, :before_execution) }.not_to raise_error
        expect(executed_callbacks).to be_empty
      end
    end

    context "with invalid callback types" do
      it "raises UnknownCallbackError for unknown type" do
        expect { registry.call(callback_task, :invalid_callback) }.to raise_error(
          CMDx::UnknownCallbackError,
          "unknown callback invalid_callback"
        )
      end
    end

    context "with error handling" do
      it "allows task errors to propagate" do
        error_task = create_task_class do
          def error_method
            raise StandardError, "callback error"
          end

          def call
            context.executed = true
          end
        end.new

        registry.register(:before_execution, :error_method)

        expect { registry.call(error_task, :before_execution) }.to raise_error(StandardError, "callback error")
      end
    end
  end

  describe "#to_h" do
    it "returns deep copy of registry" do
      registry.register(:before_execution, :setup)
      registry.register(:after_execution, :cleanup)

      result = registry.to_h

      expect(result).to eq(
        before_execution: [[[:setup], {}]],
        after_execution: [[[:cleanup], {}]]
      )
    end

    it "returns independent copy" do
      registry.register(:before_execution, :setup)

      result = registry.to_h
      result[:before_execution] << [[:additional], {}]

      expect(registry.registry[:before_execution]).to eq([[[:setup], {}]])
    end

    it "returns empty hash for empty registry" do
      expect(registry.to_h).to eq({})
    end
  end
end
