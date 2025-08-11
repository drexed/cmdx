# frozen_string_literal: true

module CMDx

  TestError = Class.new(StandardError)

  module Testing
    module TaskBuilders

      # Base

      def create_task_class(name: "AnonymousTask", &block)
        task_class = Class.new(CMDx::Task)
        task_class.define_singleton_method(:name) { name.to_s + rand(9999).to_s.rjust(4, "0") }
        task_class.class_eval(&block) if block_given?
        task_class
      end

      # Simple

      def create_successful_task(name: "SuccessfulTask", &block)
        task_class = create_task_class(name:)
        task_class.class_eval(&block) if block_given?
        task_class.define_method(:work) { context.executed = true }
        task_class
      end

      def create_failing_task(name: "FailingTask", reason: nil, **metadata, &block)
        task_class = create_task_class(name:)
        task_class.class_eval(&block) if block_given?
        task_class.define_method(:work) { fail!(reason, **metadata) }
        task_class
      end

      def create_skipping_task(name: "SkippingTask", reason: nil, **metadata, &block)
        task_class = create_task_class(name:)
        task_class.class_eval(&block) if block_given?
        task_class.define_method(:work) { skip!(reason, **metadata) }
        task_class
      end

      def create_erroring_task(name: "ErroringTask", reason: nil, **_metadata, &block)
        task_class = create_task_class(name:)
        task_class.class_eval(&block) if block_given?
        task_class.define_method(:work) { raise TestError, reason || "borked error" }
        task_class
      end

      # Nested

      def create_nested_task(strategy: :swallow, status: :success, reason: nil, **metadata, &block)
        inner_task = create_task_class(name: "InnerTask")
        inner_task.class_eval(&block) if block_given?
        inner_task.define_method(:work) do
          case status
          when :success then (context.executed_list ||= []) << :inner
          when :skipped then skip!(reason, **metadata)
          when :failure then fail!(reason, **metadata)
          when :error then raise TestError, reason || "borked error"
          else raise "unknown status #{status}"
          end
        end

        middle_task = create_task_class(name: "MiddleTask")
        middle_task.class_eval(&block) if block_given?
        middle_task.define_method(:work) do
          case strategy
          when :swallow then inner_task.execute(context)
          when :throw then throw!(inner_task.execute(context))
          when :raise then inner_task.execute!(context)
          else raise "unknown strategy #{strategy}"
          end

          (context.executed_list ||= []) << :middle
        end

        outer_task = create_task_class(name: "OuterTask")
        outer_task.class_eval(&block) if block_given?
        outer_task.define_method(:work) do
          case strategy
          when :swallow then middle_task.execute(context)
          when :throw then throw!(middle_task.execute(context))
          when :raise then middle_task.execute!(context)
          else raise "unknown strategy #{strategy}"
          end

          (context.executed_list ||= []) << :outer
        end
        outer_task
      end

    end
  end

end
