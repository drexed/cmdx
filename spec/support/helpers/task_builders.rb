# frozen_string_literal: true

module CMDx
  module Testing
    module TaskBuilders

      def create_task_class(base: nil, name: "AnonymousTask", &block)
        task_class = Class.new(base || CMDx::Task)
        task_class.define_singleton_method(:name) do
          hash = rand(10_000).to_s.rjust(4, "0")
          "#{name}#{hash}"
        end
        task_class.class_eval(&block) if block_given?
        task_class
      end

      def create_simple_task(base: nil, name: "SimpleTask", &block)
        create_task_class(name:, base:) do
          define_method :call do
            context.executed = true
          end

          class_eval(&block) if block_given?
        end
      end
      alias create_successful_task create_simple_task

      def create_failing_task(base: nil, name: "FailingTask", reason: "Task failed", **metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            fail!(reason: reason, **metadata)
          end

          class_eval(&block) if block_given?
        end
      end

      def create_skipping_task(base: nil, name: "SkippingTask", reason: "Task skipped", **metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            skip!(reason: reason, **metadata)
          end

          class_eval(&block) if block_given?
        end
      end

      def create_erroring_task(base: nil, name: "ErroringTask", reason: "Task errored", **_metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            raise StandardError, reason
          end

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
