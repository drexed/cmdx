# frozen_string_literal: true

module CMDx
  class Retriers
    # Exponential backoff. Doubles the base delay every attempt:
    # `delay * (2 ** attempt)`.
    #
    # @api private
    module Exponential

      extend self

      # @param attempt [Integer] zero-based retry attempt
      # @param delay [Float] base delay in seconds
      # @param _prev_delay [Float, nil] ignored
      # @return [Float] computed delay
      def call(attempt, delay, _prev_delay = nil)
        delay * (2**attempt)
      end

    end
  end
end
