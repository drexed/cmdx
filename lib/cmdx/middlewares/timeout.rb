# frozen_string_literal: true

module CMDx

  # Custom exception raised when task execution exceeds the configured timeout limit.
  # Inherits from Interrupt to provide consistent error handling for timeout scenarios
  # and allow proper interruption of long-running tasks.
  TimeoutError = Class.new(Interrupt)

  module Middlewares
    # Middleware that provides execution timeout protection for tasks.
    # Automatically interrupts task execution if it exceeds the specified time limit,
    # preventing runaway processes and ensuring system responsiveness.
    #
    # @since 1.0.0
    class Timeout < CMDx::Middleware

      # @return [Integer, Float, Symbol, Proc] The timeout value in seconds
      attr_reader :seconds

      # @return [Hash] The conditional options for timeout application
      attr_reader :conditional

      # Initializes the timeout middleware with optional configuration.
      #
      # @param options [Hash] configuration options for the middleware
      # @option options [Integer, Float, Symbol, Proc] :seconds timeout duration in seconds (default: 3)
      # @option options [Symbol, Proc] :if condition that must be truthy to apply timeout
      # @option options [Symbol, Proc] :unless condition that must be falsy to apply timeout
      #
      # @return [Timeout] new instance of the middleware
      #
      # @example Register with a middleware instance
      #   use :middleware, CMDx::Middlewares::Timeout.new(seconds: 30)
      #
      # @example Register with fixed timeout
      #   use :middleware, CMDx::Middlewares::Timeout, seconds: 30
      #
      # @example Register with dynamic timeout
      #   use :middleware, CMDx::Middlewares::Timeout, seconds: -> { Rails.env.test? ? 1 : 10 }
      #
      # @example Register with conditions
      #   use :middleware, CMDx::Middlewares::Timeout, seconds: 5, if: :long_running?, unless: :skip_timeout?
      def initialize(options = {})
        @seconds     = options[:seconds] || 3
        @conditional = options.slice(:if, :unless)
      end

      # Executes the middleware, wrapping task execution with timeout protection.
      # Evaluates conditions, determines timeout duration, and executes the task within
      # the timeout boundary to prevent runaway execution.
      #
      # @param task [CMDx::Task] the task being executed
      # @param callable [Proc] the callable that executes the task
      #
      # @return [Object] the result of the task execution
      #
      # @raise [TimeoutError] when task execution exceeds the timeout limit
      #
      # @example Task using timeout middleware
      #   class ProcessFileTask < CMDx::Task
      #     use :middleware, CMDx::Middlewares::Timeout, seconds: 10
      #
      #     def call
      #       # Task execution is automatically wrapped with timeout protection
      #     end
      #   end
      #
      # @example Global configuration with conditional timeout
      #   CMDx.configure do |config|
      #     config.middlewares.register CMDx::Middlewares::Timeout, seconds: 30, if: :large_dataset?
      #   end
      def call(task, callable)
        # Check if timeout should be applied based on conditions
        return callable.call(task) unless task.cmdx_eval(conditional)

        # Get seconds using yield for dynamic generation
        limit = task.cmdx_yield(seconds) || 3

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
