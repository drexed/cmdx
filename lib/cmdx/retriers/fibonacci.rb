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

      # @param attempt [Integer] zero-based retry attempt
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(attempt, delay, _prev_delay = nil)
        delay * sequence(attempt + 1)
      end

      private

      def sequence(n)
        a = 0
        b = 1
        n.times { a, b = b, a + b }
        a
      end

    end
  end
end
