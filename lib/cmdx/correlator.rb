# frozen_string_literal: true

module CMDx
  # Thread-local correlation ID management for tracing and tracking execution context.
  #
  # This module provides utilities for managing correlation IDs within thread-local storage,
  # enabling request tracing and execution context tracking across task chains and workflows.
  # Each thread maintains its own correlation ID that can be used to correlate related operations.
  module Correlator

    THREAD_KEY = :cmdx_correlation_id

    module_function

    # Generates a new unique correlation ID using SecureRandom.
    # Prefers UUID v7 when available, falls back to UUID v4.
    #
    # @return [String] a new UUID string for use as correlation ID
    #
    # @example Generate a new correlation ID
    #   CMDx::Correlator.generate #=> "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    def generate
      return SecureRandom.uuid_v7 if SecureRandom.respond_to?(:uuid_v7)

      SecureRandom.uuid
    end

    # Retrieves the current thread's correlation ID.
    #
    # @return [String, nil] the current correlation ID or nil if not set
    #
    # @example Get current correlation ID
    #   CMDx::Correlator.id #=> "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    #
    # @example When no correlation ID is set
    #   CMDx::Correlator.id #=> nil
    def id
      Thread.current[THREAD_KEY]
    end

    # Sets the current thread's correlation ID.
    #
    # @param value [String, Symbol] the correlation ID to set
    #
    # @return [String, Symbol] the value that was set
    #
    # @example Set correlation ID
    #   CMDx::Correlator.id = "custom-trace-123"
    #   CMDx::Correlator.id #=> "custom-trace-123"
    def id=(value)
      Thread.current[THREAD_KEY] = value
    end

    # Clears the current thread's correlation ID.
    #
    # @return [nil] always returns nil
    #
    # @example Clear correlation ID
    #   CMDx::Correlator.clear
    #   CMDx::Correlator.id #=> nil
    def clear
      Thread.current[THREAD_KEY] = nil
    end

    # Temporarily uses a correlation ID for the duration of a block.
    # Restores the previous correlation ID after the block completes, even if an exception occurs.
    #
    # @param value [String, Symbol] the correlation ID to use during block execution
    #
    # @return [Object] the result of the block execution
    #
    # @raise [TypeError] if value is not a String or Symbol
    #
    # @example Use temporary correlation ID
    #   CMDx::Correlator.use("temp-123") do
    #     puts CMDx::Correlator.id  #=> "temp-123"
    #     # ... perform work ...
    #   end
    #   # Previous correlation ID is restored
    #
    # @example With exception handling
    #   CMDx::Correlator.id = "original"
    #   CMDx::Correlator.use("temp") do
    #     raise StandardError, "oops"
    #   end
    #   # CMDx::Correlator.id is still "original"
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
