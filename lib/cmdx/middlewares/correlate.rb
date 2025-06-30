# frozen_string_literal: true

module CMDx
  module Middlewares
    ##
    # Correlation middleware for ensuring consistent correlation ID context during task execution.
    #
    # The Correlate middleware establishes and maintains correlation ID context throughout
    # task execution, enabling seamless request tracking across task boundaries. It ensures
    # that all tasks within an execution chain share the same correlation identifier for
    # comprehensive traceability and debugging.
    #
    # ## Correlation ID Precedence
    #
    # The middleware determines the correlation ID using the following precedence:
    # 1. **Current thread correlation** - Existing correlation from `CMDx::Correlator.id`
    # 2. **Run identifier** - The task's run ID if no thread correlation exists
    # 3. **Generated UUID** - New correlation ID if neither of the above is available
    #
    # ## Thread Safety
    #
    # The middleware uses `CMDx::Correlator.use` to establish a correlation context
    # that is automatically restored after task execution, ensuring thread-local
    # isolation and proper cleanup even in case of exceptions.
    #
    # ## Integration with CMDx Framework
    #
    # - **Automatic activation**: Can be applied globally or per-task via `use` directive
    # - **Run integration**: Works seamlessly with CMDx::Run correlation inheritance
    # - **Nested tasks**: Maintains correlation context across nested task calls
    # - **Exception safety**: Restores correlation context even when tasks fail
    #
    # @example Global middleware configuration
    #   CMDx.configure do |config|
    #     config.middlewares = [CMDx::Middlewares::Correlate]
    #   end
    #
    #   # All tasks now automatically maintain correlation context
    #   result = ProcessOrderTask.call(order_id: 123)
    #   result.run.id  # => Correlation ID maintained throughout execution
    #
    # @example Task-specific middleware application
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       # Task execution maintains correlation context
    #       SendEmailTask.call(context)  # Inherits same correlation
    #     end
    #   end
    #
    # @example Middleware with pre-established correlation
    #   CMDx::Correlator.id = "user-request-456"
    #
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       # Uses "user-request-456" as correlation ID
    #       context.correlation_used = CMDx::Correlator.id
    #     end
    #   end
    #
    #   result = ProcessOrderTask.call(order_id: 123)
    #   result.context.correlation_used  # => "user-request-456"
    #
    # @example Nested task correlation propagation
    #   class ParentTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       # Correlation established at parent level
    #       ChildTask.call(context)
    #     end
    #   end
    #
    #   class ChildTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       # Inherits parent's correlation ID
    #       context.child_correlation = CMDx::Correlator.id
    #     end
    #   end
    #
    # @example Exception handling with correlation restoration
    #   class RiskyTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       raise StandardError, "Task failed"
    #     end
    #   end
    #
    #   CMDx::Correlator.id = "original-correlation"
    #
    #   begin
    #     RiskyTask.call
    #   rescue StandardError
    #     CMDx::Correlator.id  # => "original-correlation" (properly restored)
    #   end
    #
    # @see CMDx::Correlator Thread-safe correlation ID management
    # @see CMDx::Run Run execution context with correlation inheritance
    # @see CMDx::Middleware Base middleware class
    # @since 1.0.0
    class Correlate < CMDx::Middleware

      ##
      # Executes the task within a managed correlation context.
      #
      # Establishes a correlation ID using the precedence hierarchy and executes
      # the task within that correlation context. The correlation ID is automatically
      # restored after task completion, ensuring proper cleanup and thread isolation.
      #
      # The correlation ID determination follows this precedence:
      # 1. Current thread correlation (CMDx::Correlator.id)
      # 2. Task's run ID (task.run.id)
      # 3. Generated UUID (CMDx::Correlator.generate)
      #
      # @param task [CMDx::Task] the task instance to execute
      # @param callable [#call] the callable that executes the task
      # @return [CMDx::Result] the task execution result
      #
      # @example Basic middleware execution
      #   middleware = CMDx::Middlewares::Correlate.new
      #   task = ProcessOrderTask.new(order_id: 123)
      #   callable = -> { task.call }
      #
      #   result = middleware.call(task, callable)
      #   # Task executed within correlation context
      #
      # @example Correlation ID precedence in action
      #   # Scenario 1: Thread correlation exists
      #   CMDx::Correlator.id = "thread-correlation"
      #   middleware.call(task, callable)  # Uses "thread-correlation"
      #
      #   # Scenario 2: No thread correlation, use run ID
      #   CMDx::Correlator.clear
      #   task.run.id = "run-12345"
      #   middleware.call(task, callable)  # Uses "run-12345"
      #
      #   # Scenario 3: No correlation or run ID, generate new
      #   CMDx::Correlator.clear
      #   task.run.id = nil
      #   middleware.call(task, callable)  # Uses generated UUID
      def call(task, callable)
        # Get correlation ID from current thread, run, or generate new one
        run_id = CMDx::Correlator.id || task.run.id || CMDx::Correlator.generate

        # Execute task with correlation context
        CMDx::Correlator.use(run_id) do
          callable.call(task)
        end
      end

    end
  end
end
