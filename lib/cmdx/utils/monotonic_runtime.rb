# frozen_string_literal: true

module CMDx
  module Utils
    # Utility for measuring execution time using monotonic clock.
    #
    # MonotonicRuntime provides accurate execution time measurement that is
    # unaffected by system clock adjustments, leap seconds, or other time
    # synchronization events. Uses Ruby's Process.clock_gettime with
    # CLOCK_MONOTONIC for reliable performance measurements.
    #
    # @example Basic runtime measurement
    #   runtime = Utils::MonotonicRuntime.call do
    #     sleep(1.5)
    #     # ... task execution code ...
    #   end
    #   # => 1500 (milliseconds)
    #
    # @example Task execution timing
    #   class ProcessOrderTask < CMDx::Task
    #     def call
    #       runtime = Utils::MonotonicRuntime.call do
    #         # Complex business logic
    #         process_payment
    #         update_inventory
    #         send_confirmation
    #       end
    #       logger.info "Order processed in #{runtime}ms"
    #     end
    #   end
    #
    # @example Performance benchmarking
    #   fast_time = Utils::MonotonicRuntime.call { fast_algorithm }
    #   slow_time = Utils::MonotonicRuntime.call { slow_algorithm }
    #   puts "Fast algorithm is #{slow_time / fast_time}x faster"
    #
    # @see CMDx::Task Uses this internally to measure task execution time
    # @see CMDx::Result#runtime Contains the measured execution time
    module MonotonicRuntime

      module_function

      # Measures the execution time of a given block using monotonic clock.
      #
      # Executes the provided block and returns the elapsed time in milliseconds.
      # Uses Process.clock_gettime with CLOCK_MONOTONIC to ensure accurate
      # timing that is immune to system clock changes.
      #
      # @yield Block of code to measure execution time for
      # @return [Integer] Execution time in milliseconds
      #
      # @example Simple timing measurement
      #   time_taken = MonotonicRuntime.call do
      #     expensive_operation
      #   end
      #   puts "Operation took #{time_taken}ms"
      #
      # @example Database query timing
      #   query_time = MonotonicRuntime.call do
      #     User.joins(:orders).where(active: true).count
      #   end
      #   logger.debug "Query executed in #{query_time}ms"
      #
      # @example API call timing with error handling
      #   api_time = MonotonicRuntime.call do
      #     begin
      #       external_api.fetch_data
      #     rescue => e
      #       logger.error "API call failed: #{e.message}"
      #       raise
      #     end
      #   end
      #   # Time is measured even if an exception occurs
      #
      # @note The block's return value is discarded; only execution time is returned
      # @note Uses millisecond precision for practical performance monitoring
      # @note Monotonic clock ensures accurate timing regardless of system clock changes
      def call(&)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        yield
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        finish - start
      end

    end
  end
end
