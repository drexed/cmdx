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
    # 1. **Explicit correlation ID** - Value provided during middleware initialization
    # 2. **Current thread correlation** - Existing correlation from `CMDx::Correlator.id`
    # 3. **Chain identifier** - The task's chain ID if no thread correlation exists
    # 4. **Generated UUID** - New correlation ID if none of the above is available
    #
    # ## Conditional Execution
    #
    # The middleware supports conditional execution using `:if` and `:unless` options:
    # - `:if` - Only applies correlation when the condition evaluates to true
    # - `:unless` - Only applies correlation when the condition evaluates to false
    # - Conditions can be Procs, method symbols, or boolean values
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
    # - **Chain integration**: Works seamlessly with CMDx::Chain correlation inheritance
    # - **Nested tasks**: Maintains correlation context across nested task calls
    # - **Exception safety**: Restores correlation context even when tasks fail
    #
    # @example Basic task-specific middleware application
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate
    #
    #     def call
    #       # Task execution maintains correlation context
    #       SendEmailTask.call(context)  # Inherits same correlation
    #     end
    #   end
    #
    # @example Middleware with explicit correlation ID
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate, id: "order-processing-123"
    #
    #     def call
    #       # Always uses "order-processing-123" as correlation ID
    #       context.correlation_used = CMDx::Correlator.id
    #     end
    #   end
    #
    #   result = ProcessOrderTask.call(order_id: 123)
    #   result.context.correlation_used  # => "order-processing-123"
    #
    # @example Middleware with dynamic correlation ID using procs
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate, id: -> { "order-#{order_id}-#{Time.current.to_i}" }
    #
    #     def call
    #       # Uses dynamically generated correlation ID
    #       context.correlation_used = CMDx::Correlator.id
    #     end
    #   end
    #
    #   result = ProcessOrderTask.call(order_id: 456)
    #   result.context.correlation_used  # => "order-456-1703123456"
    #
    # @example Middleware with method-based correlation ID
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate, id: :generate_order_correlation
    #
    #     def call
    #       # Uses correlation ID from generate_order_correlation method
    #       context.correlation_used = CMDx::Correlator.id
    #     end
    #
    #     private
    #
    #     def generate_order_correlation
    #       "order-#{order_id}-#{context.request_id}"
    #     end
    #   end
    #
    # @example Conditional correlation based on environment
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate, unless: -> { Rails.env.test? }
    #
    #     def call
    #       # Correlation only applied in non-test environments
    #       context.order = Order.find(order_id)
    #     end
    #   end
    #
    # @example Conditional correlation based on task state
    #   class ProcessOrderTask < CMDx::Task
    #     use CMDx::Middlewares::Correlate, if: :correlation_required?
    #
    #     def call
    #       # Correlation applied only when correlation_required? returns true
    #       context.order = Order.find(order_id)
    #     end
    #
    #     private
    #
    #     def correlation_required?
    #       context.tracking_enabled == true
    #     end
    #   end
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
    # @see CMDx::Chain Chain execution context with correlation inheritance
    # @see CMDx::Middleware Base middleware class
    # @since 1.0.0
    class Correlate < CMDx::Middleware

      # @return [String, nil] The explicit correlation ID to use
      attr_reader :id

      # @return [Hash] The conditional options for correlation application
      attr_reader :conditional

      ##
      # Initializes the Correlate middleware with optional configuration.
      #
      # @param options [Hash] configuration options for the middleware
      # @option options [String, Symbol, Proc] :id explicit correlation ID to use (takes precedence over all other sources)
      # @option options [Proc, Symbol, Boolean] :if condition that must be true for middleware to execute
      # @option options [Proc, Symbol, Boolean] :unless condition that must be false for middleware to execute
      #
      # @example Basic initialization
      #   middleware = CMDx::Middlewares::Correlate.new
      #
      # @example With explicit correlation ID
      #   middleware = CMDx::Middlewares::Correlate.new(id: "api-request-123")
      #
      # @example With conditional execution
      #   middleware = CMDx::Middlewares::Correlate.new(unless: -> { Rails.env.test? })
      #   middleware = CMDx::Middlewares::Correlate.new(if: :correlation_enabled?)
      def initialize(options = {})
        @id          = options[:id]
        @conditional = options.slice(:if, :unless)
      end

      ##
      # Executes the task within a managed correlation context.
      #
      # First evaluates any conditional execution rules (`:if` or `:unless` options).
      # If conditions allow execution, establishes a correlation ID using the
      # precedence hierarchy and executes the task within that correlation context.
      # The correlation ID is automatically restored after task completion, ensuring
      # proper cleanup and thread isolation.
      #
      # The correlation ID determination follows this precedence:
      # 1. Explicit correlation ID (provided during middleware initialization)
      #    - String/Symbol: Used as-is or called as method if task responds to it
      #    - Proc/Lambda: Executed in task context for dynamic generation
      # 2. Current thread correlation (CMDx::Correlator.id)
      # 3. Task's chain ID (task.chain.id)
      # 4. Generated UUID (CMDx::Correlator.generate)
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
      #   # Scenario 1: Explicit string correlation ID takes precedence
      #   middleware = CMDx::Middlewares::Correlate.new(id: "explicit-123")
      #   middleware.call(task, callable)  # Uses "explicit-123"
      #
      #   # Scenario 2: Dynamic correlation ID using proc
      #   middleware = CMDx::Middlewares::Correlate.new(id: -> { "dynamic-#{order_id}" })
      #   middleware.call(task, callable)  # Uses result of proc execution
      #
      #   # Scenario 3: Method-based correlation ID
      #   middleware = CMDx::Middlewares::Correlate.new(id: :correlation_method)
      #   middleware.call(task, callable)  # Uses task.correlation_method if it exists
      #
      #   # Scenario 4: Thread correlation when no explicit ID
      #   CMDx::Correlator.id = "thread-correlation"
      #   middleware = CMDx::Middlewares::Correlate.new
      #   middleware.call(task, callable)  # Uses "thread-correlation"
      #
      #   # Scenario 5: Chain ID when no explicit or thread correlation
      #   CMDx::Correlator.clear
      #   middleware.call(task, callable)  # Uses task.chain.id
      #
      #   # Scenario 6: Generated UUID when no other correlation exists
      #   CMDx::Correlator.clear
      #   # Assuming task.chain.id is nil
      #   middleware.call(task, callable)  # Uses generated UUID
      #
      # @example Conditional execution
      #   # Middleware only executes in production
      #   middleware = CMDx::Middlewares::Correlate.new(if: -> { Rails.env.production? })
      #   result = middleware.call(task, callable)
      #   # Correlation applied only in production environment
      def call(task, callable)
        # Check if correlation should be applied based on conditions
        return callable.call(task) unless task.__cmdx_eval(conditional)

        # Get correlation ID using yield for dynamic generation
        correlation_id = task.__cmdx_yield(id) || CMDx::Correlator.id || task.chain.id || CMDx::Correlator.generate

        # Execute task with correlation context
        CMDx::Correlator.use(correlation_id) do
          callable.call(task)
        end
      end

    end
  end
end
