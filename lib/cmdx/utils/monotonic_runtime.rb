# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for measuring execution time using monotonic clock.
    #
    # This module provides functionality to measure the time taken to execute
    # a block of code using the monotonic clock, which is not affected by
    # system clock adjustments and provides more accurate timing measurements.
    #
    # @since 1.0.0
    module MonotonicRuntime

      module_function

      # Measures the execution time of a given block using monotonic clock.
      #
      # @param block [Proc] the block of code to measure execution time for
      # @yield executes the provided block while measuring its runtime
      #
      # @return [Integer] the execution time in milliseconds
      #
      # @example Basic usage
      #   runtime = MonotonicRuntime.call { sleep(0.1) }
      #   # => 100 (approximately)
      #
      # @example Measuring database query time
      #   query_time = MonotonicRuntime.call { User.find(1) }
      #   # => 15 (milliseconds)
      def call(&)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        yield
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - now
      end

    end
  end
end
