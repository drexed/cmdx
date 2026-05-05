# frozen_string_literal: true

module CMDx
  class Retriers
    # Linear backoff. Sleeps `delay * (attempt + 1)` — multiples of the base
    # delay grow arithmetically (1x, 2x, 3x, ...).
    #
    # @api private
    module Linear

      extend self

      # @param attempt [Integer] zero-based retry attempt
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(attempt, delay, _prev_delay = nil)
        delay * (attempt + 1)
      end

    end
  end
end
