# frozen_string_literal: true

module CMDx
  class Deprecators
    # Emits a Ruby warning to stderr via `Kernel.warn`. Visible during
    # development and testing without polluting structured production logs.
    #
    # @api private
    module Warn

      extend self

      # @param task [Task]
      # @return [void]
      def call(task)
        Kernel.warn("[#{task.class}] DEPRECATED: migrate to a replacement or discontinue use")
      end

    end
  end
end
