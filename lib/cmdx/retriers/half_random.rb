# frozen_string_literal: true

module CMDx
  class Retriers
    # Half-random jitter. Produces a uniform delay in `[delay/2, delay]`.
    # Useful when you want a tighter spread than `:full_random` while still
    # decorrelating retries from synchronized clients.
    #
    # @api private
    module HalfRandom

      extend self

      # @param _attempt [Integer] ignored
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(_attempt, delay, _prev_delay = nil)
        (delay / 2.0) + (rand * delay / 2.0)
      end

    end
  end
end
