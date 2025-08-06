# frozen_string_literal: true

module CMDx
  module Testing
    module TaskBuilders

      def create_task_class(base: nil, name: "AnonymousTask", &block)
        task_class = Class.new(base || CMDx::Task)
        task_class.define_singleton_method(:name) { name.to_s + rand(9999).to_s.rjust(4, "0") }
        task_class.class_eval(&block) if block_given?
        task_class
      end

      def create_successful_task(base: nil, name: "SuccessfulTask", &block)
        task_class = create_task_class(base:, name:)
        task_class.define_method(:task) { context.executed = true }
        task_class.class_eval(&block) if block_given?
        task_class
      end

      def create_failing_task(base: nil, name: "FailingTask", reason: nil, **metadata, &block)
        task_class = create_task_class(base:, name:)
        task_class.define_method(:task) { fail!(reason, **metadata) }
        task_class.class_eval(&block) if block_given?
        task_class
      end

      def create_skipping_task(base: nil, name: "SkippingTask", reason: nil, **metadata, &block)
        task_class = create_task_class(base:, name:)
        task_class.define_method(:task) { skip!(reason, **metadata) }
        task_class.class_eval(&block) if block_given?
        task_class
      end

      def create_erroring_task(base: nil, name: "ErroringTask", reason: nil, **_metadata, &block)
        task_class = create_task_class(base:, name:)
        task_class.define_method(:task) { raise StandardError, reason || "system error" }
        task_class.class_eval(&block) if block_given?
        task_class
      end

    end
  end
end
