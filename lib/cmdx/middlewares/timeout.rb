# frozen_string_literal: true

module CMDx

  ##
  # Timeout middleware that enforces execution time limits on tasks.
  #
  # This middleware wraps task execution with timeout protection, automatically
  # failing tasks that exceed their configured timeout duration. The timeout
  # value can be static, dynamic, or method-based. If no timeout is specified,
  # it defaults to 3 seconds. Optionally supports conditional timeout application
  # based on task or context state.
  #
  # ## Timeout Value Types
  #
  # The middleware supports multiple ways to specify timeout values:
  # - **Static values** (Integer/Float): Fixed timeout duration
  # - **Method symbols**: Calls the specified method on the task for dynamic calculation
  # - **Procs/Lambdas**: Executed in task context for runtime timeout determination
  #
  # ## Conditional Execution
  #
  # The middleware supports conditional timeout application using `:if` and `:unless` options:
  # - `:if` - Only applies timeout when the condition evaluates to true
  # - `:unless` - Only applies timeout when the condition evaluates to false
  # - Conditions can be Procs, method symbols, or boolean values
  #
  # @example Static timeout configuration
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout, seconds: 30 # 30 seconds
  #
  #     def call
  #       # Task logic that might take too long
  #     end
  #   end
  #
  # @example Dynamic timeout using proc
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout, seconds: -> { complex_order? ? 60 : 30 }
  #
  #     def call
  #       # Task logic with dynamic timeout based on order complexity
  #     end
  #
  #     private
  #
  #     def complex_order?
  #       context.order_items.count > 10
  #     end
  #   end
  #
  # @example Method-based timeout
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout, seconds: :calculate_timeout
  #
  #     def call
  #       # Task logic with method-calculated timeout
  #     end
  #
  #     private
  #
  #     def calculate_timeout
  #       base_timeout = 30
  #       base_timeout += (context.order_items.count * 2)
  #       base_timeout
  #     end
  #   end
  #
  # @example Using default timeout (3 seconds)
  #   class QuickTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout # 3 seconds default
  #
  #     def call
  #       # Task logic with default timeout
  #     end
  #   end
  #
  # @example Conditional timeout based on task context
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout,
  #         seconds: 30,
  #         if: proc { context.enable_timeout? }
  #
  #     def call
  #       # Task logic with conditional timeout
  #     end
  #   end
  #
  # @example Conditional timeout with method reference
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout,
  #         seconds: 60,
  #         unless: :skip_timeout?
  #
  #     def call
  #       # Task logic
  #     end
  #
  #     private
  #
  #     def skip_timeout?
  #       Rails.env.development?
  #     end
  #   end
  #
  # @example Global timeout middleware
  #   class ApplicationTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout, seconds: 60 # Default 60 seconds
  #   end
  #
  # @see CMDx::Middleware Base middleware class
  # @see CMDx::Task Task settings configuration
  # @see CMDx::Workflow Workflow execution context

  ##
  # Custom timeout error class that inherits from Interrupt.
  #
  # This error is raised when task execution exceeds the configured timeout
  # duration. It provides a clean way to distinguish timeout errors from
  # other types of interruptions or exceptions.
  #
  # @example Catching timeout errors
  #   begin
  #     task.call
  #   rescue CMDx::TimeoutError => e
  #     puts "Task timed out: #{e.message}"
  #   end
  #
  # @see CMDx::Middlewares::Timeout The middleware that raises this error
  TimeoutError = Class.new(Interrupt)

  module Middlewares
    class Timeout < CMDx::Middleware

      # @return [Integer, Float, Symbol, Proc] The timeout value in seconds
      # @return [Hash] The conditional options for timeout application
      attr_reader :seconds, :conditional

      ##
      # Initializes the timeout middleware.
      #
      # @param options [Hash] Configuration options for the timeout middleware
      # @option options [Integer, Float, Symbol, Proc] :seconds Timeout value in seconds.
      #   - Integer/Float: Used as-is for static timeout
      #   - Symbol: Called as method on task if it exists, otherwise used as numeric value
      #   - Proc/Lambda: Executed in task context for dynamic timeout calculation
      #   Defaults to 3 seconds if not provided.
      # @option options [Symbol, Proc] :if Condition that must be truthy for timeout to be applied
      # @option options [Symbol, Proc] :unless Condition that must be falsy for timeout to be applied
      #
      # @example Static timeout configuration
      #   CMDx::Middlewares::Timeout.new(seconds: 30)
      #
      # @example Dynamic timeout with proc
      #   CMDx::Middlewares::Timeout.new(seconds: -> { heavy_operation? ? 120 : 30 })
      #
      # @example Method-based timeout
      #   CMDx::Middlewares::Timeout.new(seconds: :calculate_timeout_limit)
      #
      # @example Using default timeout (3 seconds)
      #   CMDx::Middlewares::Timeout.new
      #
      # @example Conditional timeout
      #   CMDx::Middlewares::Timeout.new(seconds: 30, if: :production_mode?)
      #   CMDx::Middlewares::Timeout.new(seconds: 60, unless: proc { Rails.env.test? })
      def initialize(options = {})
        @seconds     = options[:seconds] || 3
        @conditional = options.slice(:if, :unless)
      end

      ##
      # Executes the task with conditional timeout protection.
      #
      # Evaluates the conditional options to determine if timeout should be applied.
      # If conditions are met, resolves the timeout value using and wraps the task
      # execution with a timeout mechanism that will interrupt execution if it exceeds
      # the configured time limit. If conditions are not met, executes the task
      # without timeout protection.
      #
      # The timeout value determination follows this precedence:
      # 1. Explicit timeout value (provided during middleware initialization)
      #    - Integer/Float: Used as-is for static timeout
      #    - Symbol: Called as method on task if it exists, otherwise used as numeric value
      #    - Proc/Lambda: Executed in task context for dynamic timeout calculation
      # 2. Default value of 3 seconds if no timeout is specified
      #
      # @param task [CMDx::Task] The task instance to execute
      # @param callable [#call] The next middleware or task execution callable
      # @return [CMDx::Result] The task execution result
      # @raise [TimeoutError] If execution exceeds the configured timeout and conditions are met
      #
      # @example Static timeout - successful execution
      #   # Task completes in 5 seconds, timeout is 30 seconds, condition is true
      #   result = task.call  # => success
      #
      # @example Static timeout - timeout exceeded
      #   # Task would take 60 seconds, timeout is 30 seconds, condition is true
      #   result = task.call  # => failed with timeout error
      #
      # @example Dynamic timeout with proc
      #   # Task uses proc to calculate 120 seconds for complex operation
      #   # Task completes in 90 seconds
      #   result = task.call  # => success
      #
      # @example Method-based timeout
      #   # Task calls :timeout_limit method which returns 45 seconds
      #   # Task completes in 30 seconds
      #   result = task.call  # => success
      #
      # @example Condition not met
      #   # Task takes 60 seconds, timeout is 30 seconds, but condition is false
      #   result = task.call  # => success (no timeout applied)
      def call(task, callable)
        # Check if timeout should be applied based on conditions
        return callable.call(task) unless task.__cmdx_eval(conditional)

        # Get seconds using yield for dynamic generation
        limit = task.__cmdx_yield(seconds) || 3

        # Apply timeout protection
        ::Timeout.timeout(limit, TimeoutError, "execution exceeded #{limit} seconds") do
          callable.call(task)
        end
      rescue TimeoutError => e
        task.fail!(reason: "[#{e.class}] #{e.message}", original_exception: e, seconds: limit)
        task.result
      end

    end
  end

end
