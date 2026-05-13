# frozen_string_literal: true

module CMDx
  class Retriers
    # Exponential backoff. Doubles the base delay every attempt:
    # `delay * (2 ** attempt)`. The shift is saturated at {MAX_SHIFT} to keep
    # the math (and resulting sleep) bounded; pair with `:max_delay` to set
    # the true upper bound.
    #
    # @api private
    module Exponential

      extend self

      # Hard cap on the doubling exponent. `2 ** 30 ≈ 1.07e9` so paired with
      # any sensible base delay the unclamped result is large enough to be
      # noticed but never blows up into Bignum allocations or `Infinity`.
      MAX_SHIFT = 30

      # @param attempt [Integer] zero-based retry attempt
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(attempt, delay, _prev_delay = nil)
        shift = [attempt, MAX_SHIFT].min
        delay * (1 << shift)
      end

    end
  end
end
