# frozen_string_literal: true

require "timeout"

module CMDx
  module Middlewares
    # Enforces a maximum execution time for the task.
    module Timeout

      # @param _task [Task] the task instance (reserved for API symmetry)
      # @param seconds [Numeric] timeout in seconds
      #
      # @rbs (untyped _task, Numeric seconds) { () -> untyped } -> untyped
      def self.call(_task, seconds = 30, &)
        ::Timeout.timeout(seconds, &)
      rescue ::Timeout::Error
        # Stdlib ::Timeout may raise outside the Task `catch(:cmdx_signal)` scope; raise so Runtime records failure.
        raise StandardError, "execution timed out after #{seconds}s"
      end

    end
  end
end
