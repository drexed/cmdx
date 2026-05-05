# frozen_string_literal: true

module CMDx
  class Retriers
    # Bounded-random jitter. Produces a uniform delay in `[delay, 2*delay]`.
    # Guarantees at least the base delay between attempts while still
    # decorrelating retry timing.
    #
    # @api private
    module BoundedRandom

      extend self

      # @param _attempt [Integer] ignored
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(_attempt, delay, _prev_delay = nil)
        delay + (rand * delay)
      end

    end
  end
end
