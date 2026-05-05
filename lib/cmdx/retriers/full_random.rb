# frozen_string_literal: true

module CMDx
  class Retriers
    # Full-random jitter. Produces a uniform delay in `[0, delay]`. Maximizes
    # spread at the cost of occasional very-fast retries.
    #
    # @api private
    module FullRandom

      extend self

      # @param _attempt [Integer] ignored
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(_attempt, delay, _prev_delay = nil)
        rand * delay
      end

    end
  end
end
