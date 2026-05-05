# frozen_string_literal: true

module CMDx
  class Retriers
    # AWS-recommended decorrelated jitter. Produces a uniform delay in
    # `[delay, prev_delay * 3]`, threading state across attempts via
    # `prev_delay`. When no previous delay exists the upper bound collapses
    # to `3 * delay`, matching the AWS reference implementation.
    #
    # @see https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
    # @api private
    module DecorrelatedJitter

      extend self

      # @param _attempt [Integer] ignored
      # @param delay [Float] base delay in seconds (also the lower bound)
      # @param prev_delay [Float, nil] previous computed delay; falls back to
      #   `delay` so the first call samples in `[delay, 3*delay]`
      # @return [Float] computed delay
      def call(_attempt, delay, prev_delay = nil)
        base = prev_delay || delay
        delay + (rand * ((base * 3) - delay))
      end

    end
  end
end
