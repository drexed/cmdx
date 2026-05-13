# frozen_string_literal: true

module CMDx
  class Retriers
    # Fibonacci backoff. Sleeps `delay * fib(attempt + 1)` where `fib(1) == 1`,
    # `fib(2) == 1`, `fib(3) == 2`, ... Multipliers grow as 1, 1, 2, 3, 5, 8.
    # Slower-growing than exponential, faster-growing than linear.
    #
    # @api private
    module Fibonacci

      extend self

      # Hard cap on the index to keep multipliers/integer allocations bounded.
      # `fib(78) < 2**63`, well past any realistic retry attempt. Pair with
      # `:max_delay` for the actual sleep ceiling.
      MAX_INDEX = 78

      # Cache of computed Fibonacci numbers. Shared across calls so consecutive
      # retries reuse prior work instead of recomputing from zero. Reads are
      # lock-free; growth is performed on a local dup and swapped atomically
      # under the mutex.
      @cache = [0, 1].freeze
      @mutex = Mutex.new

      # @param attempt [Integer] zero-based retry attempt
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(attempt, delay, _prev_delay = nil)
        index = attempt + 1
        index = MAX_INDEX if index > MAX_INDEX
        delay * fib(index)
      end

      private

      def fib(n)
        cache = @cache
        return cache[n] if n < cache.size

        @mutex.synchronize do
          cache = @cache
          if cache.size <= n
            grown = cache.dup
            grown << (grown[-1] + grown[-2]) while grown.size <= n
            @cache = grown.freeze
          end
        end

        @cache[n]
      end

    end
  end
end
