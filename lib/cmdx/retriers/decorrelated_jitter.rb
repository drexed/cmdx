# frozen_string_literal: true

module CMDx
  class Retriers
    # AWS-recommended decorrelated jitter. Produces a uniform delay in
    # `[delay, max(prev_delay * 3, delay)]`, threading state across attempts
    # via `prev_delay`. When no previous delay exists the upper bound
    # collapses to `3 * delay`, matching the AWS reference implementation.
    # The lower bound is pinned at `delay` even when `prev_delay * 3 < delay`
    # (e.g. after `:max_delay` clamping or mixed strategies), guaranteeing
    # the returned value is never below the configured base.
    #
    # @see https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
    # @api private
    module DecorrelatedJitter

      extend self

      # @param _attempt [Integer] ignored
      # @param delay [Float] base delay in seconds (also the lower bound)
      # @param prev_delay [Float, nil] previous computed delay; falls back to
      #   `delay` so the first call samples in `[delay, 3*delay]`
      # @return [Float] computed delay, never less than `delay`
      def call(_attempt, delay, prev_delay = nil)
        base = prev_delay || delay
        high = base * 3
        high = delay if high < delay
        delay + (rand * (high - delay))
      end

    end
  end
end
