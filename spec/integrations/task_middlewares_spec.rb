# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Middlewares Integration", type: :integration do
  describe "Basic Middleware Integration" do
    it "executes simple middleware with task" do
      execution_log = []

      middleware = Class.new(CMDx::Middleware) do
        define_method :initialize do |log|
          @log = log
        end

        define_method :call do |task, callable|
          @log << "middleware_executed"
          callable.call(task)
        end
      end

      task_class = Class.new(CMDx::Task) do
        use :middleware, middleware, execution_log

        define_method :call do
          execution_log << "task_executed"
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(execution_log).to include("middleware_executed")
      expect(execution_log).to include("task_executed")
    end

    it "demonstrates middleware registration" do
      middleware_class = Class.new(CMDx::Middleware) do
        def call(task, callable)
          callable.call(task)
        end
      end

      task_class = Class.new(CMDx::Task) do
        use :middleware, middleware_class

        def call
          # Basic task execution
        end
      end

      result = task_class.call
      expect(result).to be_successful_task
    end

    it "works with built-in Correlate middleware" do
      correlation_id = "test-correlation-#{SecureRandom.hex(4)}"

      task_class = Class.new(CMDx::Task) do
        use :middleware, CMDx::Middlewares::Correlate, id: correlation_id

        def call
          context.correlation_used = CMDx::Correlator.id
        end
      end

      result = task_class.call

      expect(result).to be_successful_task
      expect(result.context.correlation_used).to eq(correlation_id)
    end
  end
end
