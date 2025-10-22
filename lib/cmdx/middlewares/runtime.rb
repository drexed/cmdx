# frozen_string_literal: true

module CMDx
  module Middlewares
    # Middleware for measuring task execution runtime.
    #
    # The Runtime middleware provides performance monitoring by measuring
    # the execution time of tasks using monotonic clock for accuracy.
    # It stores runtime measurements in task result metadata for analysis.
    module Runtime

      extend self

      # Middleware entry point that measures task execution runtime.
      #
      # Evaluates the condition from options and measures execution time
      # if enabled. Uses monotonic clock for precise timing measurements
      # and stores the result in task metadata.
      #
      # @param task [Task] The task being executed
      # @param options [Hash] Configuration options for runtime measurement
      # @option options [Symbol, Proc, Object, nil] :if Condition to enable runtime measurement
      # @option options [Symbol, Proc, Object, nil] :unless Condition to disable runtime measurement
      #
      # @yield The task execution block
      #
      # @return [Object] The result of task execution
      #
      # @example Basic usage with automatic runtime measurement
      #   Runtime.call(task, &block)
      # @example Conditional runtime measurement
      #   Runtime.call(task, if: :enable_profiling, &block)
      # @example Disable runtime measurement
      #   Runtime.call(task, unless: :skip_profiling, &block)
      #
      # @rbs (Task task, **untyped options) { () -> untyped } -> untyped
      def call(task, **options)
        return yield unless Utils::Condition.evaluate(task, options)

        now = monotonic_time
        result = yield
        task.result.metadata[:runtime] = monotonic_time - now
        result
      end

      private

      # Gets the current monotonic time in milliseconds.
      #
      # Uses Process.clock_gettime with CLOCK_MONOTONIC for consistent
      # timing measurements that are not affected by system clock changes.
      #
      # @return [Integer] Current monotonic time in milliseconds
      #
      # @rbs () -> Integer
      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      end

    end
  end
end
