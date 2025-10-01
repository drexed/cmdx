# frozen_string_literal: true

module CMDx

  TestError = Class.new(StandardError)

  module Testing
    module TaskBuilders

      # Base

      def create_task_class(base: CMDx::Task, name: "AnonymousTask", &)
        task_class = Class.new(base)
        task_class.define_singleton_method(:name) { @name ||= name.to_s + rand(9999).to_s.rjust(4, "0") }
        task_class.class_eval(&) if block_given?
        task_class
      end

      # Simple

      def create_successful_task(base: CMDx::Task, name: "SuccessfulTask", &)
        task_class = create_task_class(base:, name:)
        task_class.class_eval(&) if block_given?
        task_class.define_method(:work) { (context.executed ||= []) << :success }
        task_class
      end

      def create_skipping_task(base: CMDx::Task, name: "SkippingTask", reason: nil, **metadata, &)
        task_class = create_task_class(base:, name:)
        task_class.class_eval(&) if block_given?
        task_class.define_method(:work) do
          skip!(reason, **metadata)
          (context.executed ||= []) << :skipped
        end
        task_class
      end

      def create_failing_task(base: CMDx::Task, name: "FailingTask", reason: nil, **metadata, &)
        task_class = create_task_class(base:, name:)
        task_class.class_eval(&) if block_given?
        task_class.define_method(:work) do
          fail!(reason, **metadata)
          (context.executed ||= []) << :failed
        end
        task_class
      end

      def create_erroring_task(base: CMDx::Task, name: "ErroringTask", reason: nil, **_metadata, &)
        task_class = create_task_class(base:, name:)
        task_class.class_eval(&) if block_given?
        task_class.define_method(:work) do
          raise TestError, reason || "borked error"
          (context.executed ||= []) << :errored # rubocop:disable Lint/UnreachableCode
        end
        task_class
      end

      # Nested

      def create_nested_task(base: CMDx::Task, strategy: :swallow, status: :success, reason: nil, **metadata, &)
        inner_task = create_task_class(base:, name: "InnerTask")
        inner_task.class_eval(&) if block_given?
        inner_task.define_method(:work) do
          case status
          when :success then (context.executed ||= []) << :inner
          when :skipped then skip!(reason, **metadata)
          when :failure then fail!(reason, **metadata)
          when :error then raise TestError, reason || "borked error"
          else raise "unknown status #{status}"
          end
        end

        middle_task = create_task_class(base:, name: "MiddleTask")
        middle_task.class_eval(&) if block_given?
        middle_task.define_method(:work) do
          case strategy
          when :swallow then inner_task.execute(context)
          when :throw, :raise_throw then throw!(inner_task.execute(context))
          when :raise, :throw_raise then inner_task.execute!(context)
          else raise "unknown strategy #{strategy}"
          end

          (context.executed ||= []) << :middle
        end

        outer_task = create_task_class(base:, name: "OuterTask")
        outer_task.class_eval(&) if block_given?
        outer_task.define_method(:work) do
          case strategy
          when :swallow then middle_task.execute(context)
          when :throw, :throw_raise then throw!(middle_task.execute(context))
          when :raise, :raise_throw then middle_task.execute!(context)
          else raise "unknown strategy #{strategy}"
          end

          (context.executed ||= []) << :outer
        end
        outer_task
      end

    end
  end

end
