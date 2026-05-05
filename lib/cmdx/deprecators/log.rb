# frozen_string_literal: true

module CMDx
  class Deprecators
    # Writes a `warn`-level entry to the task's logger noting the deprecation.
    # Execution proceeds; useful for gradual migration where you want
    # observability without breaking callers.
    #
    # @api private
    module Log

      extend self

      # @param task [Task]
      # @return [void]
      def call(task)
        task.logger.warn { "DEPRECATED: #{task.class} - migrate to a replacement or discontinue use" }
      end

    end
  end
end
