# frozen_string_literal: true

module CMDx
  module Middlewares
    # Assigns a correlation ID to the context for tracing.
    module Correlate

      # @param task [Task] the task instance
      # @param key [Symbol] the context key
      #
      # @rbs (untyped task, ?Symbol key) { () -> untyped } -> untyped
      def self.call(task, key = :correlation_id, &)
        task.context.fetch_or_store(key) { Identifier.generate }
        yield
      end

    end
  end
end
