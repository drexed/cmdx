# frozen_string_literal: true

require "timeout"

module CMDx

  ##
  # Timeout middleware that enforces execution time limits on tasks.
  #
  # This middleware wraps task execution with timeout protection, automatically
  # failing tasks that exceed their configured timeout duration. If no timeout
  # is specified, it defaults to 3 seconds. Optionally supports conditional
  # timeout application based on task or context state.
  #
  # @example Hash-based timeout configuration
  #   class ProcessOrderTask < CMDx::Task
  #     use CMDx::Middlewares::Timeout, seconds: 30 # 30 seconds
  #
  #     def call
  #       # Task logic that might take too long
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
  # @see CMDx::Batch Batch execution context

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

      # @return [Integer, Float] The timeout value in seconds
      attr_reader :seconds

      # @return [Hash] The conditional options for timeout application
      attr_reader :conditional

      ##
      # Initializes the timeout middleware.
      #
      # @param options [Hash] Configuration options for the timeout middleware
      # @option options [Integer, Float] :seconds Timeout value in seconds.
      #   Defaults to 3 seconds if not provided.
      # @option options [Symbol, Proc] :if Condition that must be truthy for timeout to be applied
      # @option options [Symbol, Proc] :unless Condition that must be falsy for timeout to be applied
      #
      # @example Hash-based configuration
      #   CMDx::Middlewares::Timeout.new(seconds: 30)
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
      # If conditions are met, wraps the task execution with a timeout mechanism
      # that will interrupt execution if it exceeds the configured time limit.
      # If conditions are not met, executes the task without timeout protection.
      #
      # @param task [CMDx::Task] The task instance to execute
      # @param callable [#call] The next middleware or task execution callable
      # @return [CMDx::Result] The task execution result
      # @raise [TimeoutError] If execution exceeds the configured timeout and conditions are met
      #
      # @example Successful execution within timeout
      #   # Task completes in 5 seconds, timeout is 30 seconds, condition is true
      #   result = task.call  # => success
      #
      # @example Timeout exceeded
      #   # Task would take 60 seconds, timeout is 30 seconds, condition is true
      #   result = task.call  # => failed with timeout error
      #
      # @example Condition not met
      #   # Task takes 60 seconds, timeout is 30 seconds, but condition is false
      #   result = task.call  # => success (no timeout applied)
      def call(task, callable)
        # Check if timeout should be applied based on conditions
        return callable.call(task) unless task.__cmdx_eval(conditional)

        # Apply timeout protection
        ::Timeout.timeout(seconds, TimeoutError, "execution exceeded #{@seconds} seconds") do
          callable.call(task)
        end
      rescue TimeoutError => e
        task.fail!(reason: "[#{e.class}] #{e.message}", original_exception: e, seconds:)
        task.result
      end

    end
  end

end
