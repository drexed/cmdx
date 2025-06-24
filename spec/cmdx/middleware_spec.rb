# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middleware do
  it_behaves_like "a middleware"

  describe "#call" do
    subject(:middleware) { described_class.new }

    context "when not overridden" do
      it "raises UndefinedCallError with descriptive message" do
        task = class_double("Task")
        callable = instance_double("callable")

        expect { middleware.call(task, callable) }.to raise_error(
          CMDx::UndefinedCallError, "call method not defined in CMDx::Middleware"
        )
      end
    end
  end

  describe "custom middleware implementation" do
    include_context "with middleware chain behavior"

    let(:custom_middleware_class) do
      Class.new(described_class) do
        def initialize(prefix = "") # rubocop:disable Lint/MissingSuper
          @prefix = prefix
        end

        def call(task, callable)
          task.context.middleware_calls ||= []
          task.context.middleware_calls << "#{@prefix}before"

          result = callable.call(task)

          task.context.middleware_calls << "#{@prefix}after"
          result
        end
      end
    end

    context "with basic middleware execution" do
      subject do
        middleware = custom_middleware_class.new("test_")
        middleware.call(task, lambda { |t|
          t.call
          t.result
        })
      end

      it_behaves_like "middleware execution", %w[test_before task_executed test_after]
    end

    context "with multiple custom middleware instances" do
      subject do
        # Simulate nested middleware execution
        logging = logging_middleware.new
        timing = timing_middleware.new

        logging.call(task, lambda { |t|
          timing.call(t, lambda { |inner_task|
            inner_task.call
            inner_task.result
          })
        })
      end

      let(:logging_middleware) do
        Class.new(described_class) do
          def call(task, callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "log_start"

            result = callable.call(task)

            task.context.middleware_calls << "log_end"
            result
          end
        end
      end

      let(:timing_middleware) do
        Class.new(described_class) do
          def call(task, callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "time_start"

            result = callable.call(task)

            task.context.middleware_calls << "time_end"
            result
          end
        end
      end

      it_behaves_like "middleware execution", %w[log_start time_start task_executed time_end log_end]
    end

    context "with middleware that modifies task context" do
      let(:context_middleware) do
        Class.new(described_class) do
          def call(task, callable)
            task.context.processed_by_middleware = true
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "context_modified"

            callable.call(task)
          end
        end
      end

      it "allows middleware to modify task context" do
        middleware = context_middleware.new
        result = middleware.call(task, lambda { |t|
          t.call
          t.result
        })

        expect(task.context.processed_by_middleware).to be true
        expect(task.context.middleware_calls).to include("context_modified")
        expect(result).to be_a(CMDx::Result)
      end
    end

    context "with middleware that handles task failures" do
      let(:error_handling_middleware) do
        Class.new(described_class) do
          def call(task, callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "error_handler_before"

            result = callable.call(task)

            task.context.middleware_calls << "error_handled" if result.failed?

            task.context.middleware_calls << "error_handler_after"
            result
          end
        end
      end

      let(:failing_task_class) do
        Class.new(CMDx::Task) do
          def call
            context.middleware_calls ||= []
            context.middleware_calls << "task_executed"
            fail!(reason: "Something went wrong")
          end
        end
      end

      it "can handle and respond to task failures" do
        failing_task = failing_task_class.send(:new, {})
        middleware = error_handling_middleware.new

        result = middleware.call(failing_task, lambda { |t|
          begin
            t.call
          rescue CMDx::Failed
            # Task failure is expected, let the middleware handle it
          end
          t.result
        })

        expect(failing_task.context.middleware_calls).to eq(
          %w[error_handler_before task_executed error_handled error_handler_after]
        )
        expect(result.failed?).to be true
      end
    end
  end
end
