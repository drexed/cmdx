# frozen_string_literal: true

module CMDx

  # Error raised when task execution exceeds the configured timeout limit.
  #
  # This error occurs when a task takes longer to execute than the specified
  # time limit. Timeout errors are raised by Ruby's Timeout module and are
  # caught by the middleware to properly fail the task with timeout information.
  TimeoutError = Class.new(Interrupt)

  module Middlewares
    # Middleware for enforcing execution time limits on tasks.
    #
    # The Timeout middleware provides execution time control by wrapping
    # task execution with Ruby's Timeout module. It automatically fails
    # tasks that exceed the configured time limit and provides detailed
    # error information including the exceeded limit.
    module Timeout

      extend self

      # Default timeout limit in seconds when none is specified.
      DEFAULT_LIMIT = 3

      # Middleware entry point that enforces execution time limits.
      #
      # Evaluates the condition from options and applies timeout control
      # if enabled. Supports various timeout limit configurations including
      # numeric values, task method calls, and dynamic proc evaluation.
      #
      # @param task [Task] The task being executed
      # @param options [Hash] Configuration options for timeout control
      # @option options [Numeric, Symbol, Proc, Object] :seconds The timeout limit source
      # @option options [Symbol, Proc, Object, nil] :if Condition to enable timeout control
      # @option options [Symbol, Proc, Object, nil] :unless Condition to disable timeout control
      #
      # @yield The task execution block
      #
      # @return [Object] The result of task execution
      #
      # @raise [TimeoutError] When execution exceeds the configured limit
      #
      # @example Basic usage with default 3 second timeout
      #   Timeout.call(task, &block)
      # @example Custom timeout limit in seconds
      #   Timeout.call(task, seconds: 10, &block)
      # @example Use task method for timeout limit
      #   Timeout.call(task, seconds: :timeout_limit, &block)
      # @example Use proc for dynamic timeout calculation
      #   Timeout.call(task, seconds: -> { calculate_timeout }, &block)
      # @example Conditional timeout control
      #   Timeout.call(task, if: :enable_timeout, &block)
      def call(task, **options, &)
        return yield unless Utils::Condition.evaluate(task, options)

        limit =
          case callable = options[:seconds]
          when Numeric then callable
          when Symbol then task.send(callable)
          when Proc then task.instance_eval(&callable)
          else callable.respond_to?(:call) ? callable.call(task) : DEFAULT_LIMIT
          end

        ::Timeout.timeout(limit, TimeoutError, "execution exceeded #{limit} seconds", &)
      rescue TimeoutError => e
        task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e, limit:) }
      end

    end
  end

end
