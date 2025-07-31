# frozen_string_literal: true

module CMDx
  # Thread-safe correlation ID management for distributed tracing and request tracking.
  #
  # Correlator provides functionality to generate, store, and manage correlation IDs
  # across thread boundaries for request tracing, logging correlation, and distributed
  # system monitoring. Correlation IDs are stored in thread-local storage to ensure
  # thread safety and isolation between concurrent operations.
  module Correlator

    THREAD_KEY = :cmdx_correlation_id

    module_function

    # Generates a new correlation ID using the best available UUID algorithm.
    #
    # Attempts to use UUID v7 (time-ordered) if available in Ruby 3.3+, otherwise
    # falls back to standard UUID v4. UUID v7 provides better database indexing
    # performance and natural time-based ordering for correlation tracking.
    #
    # @return [String] a new UUID correlation ID
    #
    # @example Generate a correlation ID
    #   Correlator.generate #=> "01234567-89ab-7def-0123-456789abcdef"
    #
    # @example Using the generated ID for logging
    #   correlation_id = Correlator.generate
    #   logger.info "Request started", correlation_id: correlation_id
    def generate
      return SecureRandom.uuid_v7 if SecureRandom.respond_to?(:uuid_v7)

      SecureRandom.uuid
    end

    # Retrieves the current correlation ID for the active thread.
    #
    # Returns the correlation ID that has been set for the current thread's
    # execution context. Returns nil if no correlation ID has been established
    # for the current thread.
    #
    # @return [String, nil] the current thread's correlation ID, or nil if not set
    #
    # @example Get current correlation ID
    #   Correlator.id #=> "01234567-89ab-7def-0123-456789abcdef"
    def id
      Thread.current[THREAD_KEY]
    end

    # Sets the correlation ID for the current thread.
    #
    # Establishes a correlation ID in thread-local storage that will be
    # accessible to all operations within the current thread's execution
    # context. This ID will persist until explicitly changed or cleared.
    #
    # @param value [String, Symbol] the correlation ID to set for this thread
    #
    # @return [String, Symbol] the assigned correlation ID value
    #
    # @example Set a custom correlation ID
    #   Correlator.id = "custom-trace-123"
    #
    # @example Set a generated correlation ID
    #   Correlator.id = Correlator.generate
    def id=(value)
      Thread.current[THREAD_KEY] = value
    end

    # Clears the correlation ID for the current thread.
    #
    # Removes the correlation ID from thread-local storage, effectively
    # resetting the correlation context for the current thread. Useful
    # for cleanup between request processing or test scenarios.
    #
    # @return [nil] always returns nil after clearing
    #
    # @example Clear correlation ID
    #   Correlator.clear
    #   Correlator.id #=> nil
    def clear
      Thread.current[THREAD_KEY] = nil
    end

    # Temporarily sets a correlation ID for the duration of a block execution.
    #
    # Establishes a correlation ID context for the provided block, automatically
    # restoring the previous correlation ID when the block completes. This ensures
    # proper correlation ID isolation for nested operations or temporary contexts.
    #
    # @param value [String, Symbol] the temporary correlation ID to use during block execution
    #
    # @return [Object] the return value of the executed block
    #
    # @raise [TypeError] if the provided value is not a String or Symbol
    #
    # @example Use temporary correlation ID
    #   Correlator.use("temp-id-123") do
    #     logger.info "Processing with temporary ID"
    #     perform_operation
    #   end
    #
    # @example Nested correlation contexts
    #   Correlator.id = "parent-id"
    #   Correlator.use("child-id") do
    #     puts Correlator.id #=> "child-id"
    #   end
    #   puts Correlator.id #=> "parent-id"
    def use(value)
      unless value.is_a?(String) || value.is_a?(Symbol)
        raise TypeError,
              "must be a String or Symbol"
      end

      previous_id = id
      self.id = value
      yield
    ensure
      self.id = previous_id
    end

  end
end
