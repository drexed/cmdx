# frozen_string_literal: true

module CMDx
  class Deprecators
    # Raises {DeprecationError} to prevent the task from executing. Use for
    # tasks that must no longer run.
    #
    # @api private
    module Error

      extend self

      # @param task [Task]
      # @return [void]
      # @raise [DeprecationError]
      def call(task)
        raise DeprecationError,
          "#{task.class} is deprecated and prohibited from execution. " \
          "See https://drexed.github.io/cmdx/deprecation/#error"
      end

    end
  end
end
