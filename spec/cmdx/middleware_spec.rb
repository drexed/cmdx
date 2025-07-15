# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middleware do
  subject(:middleware) { described_class.new }

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      task = double("task")
      callable = -> { "result" }

      allow_any_instance_of(described_class).to receive(:call).with(task, callable).and_return("delegated")

      result = described_class.call(task, callable)

      expect(result).to eq("delegated")
    end

    it "passes task and callable to instance call method" do
      task = double("task")
      callable = -> { "test_result" }

      allow_any_instance_of(described_class).to receive(:call).with(task, callable).and_return("middleware_result")

      result = described_class.call(task, callable)

      expect(result).to eq("middleware_result")
    end
  end

  describe "#call" do
    it "raises UndefinedCallError with descriptive message" do
      task = double("task")
      callable = -> { "result" }

      expect { middleware.call(task, callable) }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Middleware"
      )
    end
  end

  describe "subclass implementation" do
    let(:working_middleware_class) do
      Class.new(described_class) do
        def call(task, callable)
          "before_#{task.class.name}_#{callable.call}_after"
        end
      end
    end

    let(:broken_middleware_class) do
      Class.new(described_class) do
        # Intentionally doesn't implement call method
      end
    end

    let(:task) { double("task", class: double(name: "TestTask")) }
    let(:callable) { -> { "executed" } }

    it "works when subclass properly implements call method" do
      result = working_middleware_class.call(task, callable)

      expect(result).to eq("before_TestTask_executed_after")
    end

    it "raises error when subclass doesn't implement call method" do
      expect { broken_middleware_class.call(task, callable) }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "integration with task system" do
    it "wraps task execution with custom behavior" do
      logging_middleware = Class.new(described_class) do
        def call(task, callable)
          task.context.middleware_started = true
          result = callable.call(task)
          task.context.middleware_finished = true
          result
        end
      end

      task_class = create_task_class(name: "LoggingMiddlewareTask") do
        use :middleware, logging_middleware

        def call
          context.executed = true
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(result.context.executed).to be true
      expect(result.context.middleware_started).to be true
      expect(result.context.middleware_finished).to be true
    end

    it "can modify task context during execution" do
      context_middleware = Class.new(described_class) do
        def call(task, callable)
          task.context.middleware_data = "set by middleware"
          callable.call(task)
        end
      end

      task_class = create_task_class(name: "ContextMiddlewareTask") do
        use :middleware, context_middleware

        def call
          context.executed = true
          context.task_data = "set by task"
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(result.context.executed).to be true
      expect(result.context.middleware_data).to eq("set by middleware")
      expect(result.context.task_data).to eq("set by task")
    end

    it "handles multiple middleware in order" do
      first_middleware = Class.new(described_class) do
        def call(task, callable)
          task.context.first_middleware = true
          callable.call(task)
        end
      end

      second_middleware = Class.new(described_class) do
        def call(task, callable)
          task.context.second_middleware = true
          callable.call(task)
        end
      end

      task_class = create_task_class(name: "MultipleMiddlewareTask") do
        use :middleware, first_middleware
        use :middleware, second_middleware

        def call
          context.executed = true
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(result.context.executed).to be true
      expect(result.context.first_middleware).to be true
      expect(result.context.second_middleware).to be true
    end

    it "integrates with the task system architecture" do
      simple_middleware = Class.new(described_class) do
        def call(task, callable)
          task.context.middleware_executed = true
          callable.call(task)
        end
      end

      task_class = create_task_class(name: "IntegratedMiddlewareTask") do
        use :middleware, simple_middleware

        def call
          context.task_executed = true
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(result.context.task_executed).to be true
      expect(result.context.middleware_executed).to be true
    end
  end
end
