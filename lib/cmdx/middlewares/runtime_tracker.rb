# frozen_string_literal: true

module CMDx
  module Middlewares
    # Tracks the wall clock time of task execution in the context.
    module RuntimeTracker

      # @param task [Task] the task instance
      # @param key [Symbol] the context key for storing the duration
      #
      # @rbs (untyped task, ?Symbol key) { () -> untyped } -> untyped
      def self.call(task, key = :runtime_ms, &)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
        task.context[key] = elapsed
      end

    end
  end
end
