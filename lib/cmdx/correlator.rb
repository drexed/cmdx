# frozen_string_literal: true

module CMDx
  ##
  # Thread-safe correlation ID management for tracking related operations across request boundaries.
  #
  # The Correlator provides a simple, thread-local storage mechanism for managing correlation
  # identifiers throughout the execution lifecycle. It enables tracing related operations
  # across different tasks, workflows, and service boundaries within the same execution context.
  #
  # Correlation IDs are automatically used by CMDx runs when available, providing seamless
  # request tracking without requiring explicit parameter passing between tasks.
  #
  # ## Thread Safety
  #
  # All correlation operations are thread-local, ensuring that different threads maintain
  # separate correlation contexts without interference. This is essential for concurrent
  # request processing in multi-threaded applications.
  #
  # ## Integration with CMDx Runs
  #
  # When a new CMDx::Chain is created, it automatically uses the current thread's correlation
  # ID as its chain identifier if available, falling back to UUID generation if none exists.
  #
  # @example Basic correlation usage
  #   CMDx::Correlator.id = "req-12345"
  #   CMDx::Correlator.id  # => "req-12345"
  #
  #   # Chain automatically inherits correlation ID
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.chain.id  # => "req-12345"
  #
  # @example Block-based correlation context
  #   CMDx::Correlator.use("workflow-operation-456") do
  #     # All tasks within this block share the same correlation
  #     ProcessOrderTask.call(order_id: 123)
  #     SendEmailTask.call(user_id: 456)
  #   end
  #   # Correlation context is automatically restored
  #
  # @example Nested correlation contexts
  #   CMDx::Correlator.use("parent-operation") do
  #     CMDx::Correlator.use("child-operation") do
  #       ProcessOrderTask.call(order_id: 123)
  #       # Uses "child-operation" as correlation ID
  #     end
  #     # Restored to "parent-operation"
  #     SendEmailTask.call(user_id: 456)
  #   end
  #
  # @example Manual correlation management
  #   # Set correlation ID for current thread
  #   CMDx::Correlator.id = "manual-correlation"
  #
  #   # Check current correlation
  #   current_id = CMDx::Correlator.id
  #
  #   # Clear correlation when done
  #   CMDx::Correlator.clear
  #
  # @example Middleware integration pattern
  #   class CorrelationMiddleware
  #     def call(env)
  #       correlation_id = env['HTTP_X_CORRELATION_ID'] || CMDx::Correlator.generate
  #
  #       CMDx::Correlator.use(correlation_id) do
  #         @app.call(env)
  #       end
  #     end
  #   end
  #
  # @see CMDx::Chain Chain execution context that inherits correlation IDs
  # @since 1.0.0
  module Correlator

    ##
    # Thread-local storage key for correlation identifiers.
    #
    # Uses a Symbol key to avoid potential conflicts with other thread-local
    # variables and to ensure consistent access across the correlator methods.
    #
    # @return [Symbol] the thread-local storage key
    THREAD_KEY = :cmdx_correlation_id

    module_function

    ##
    # Generates a new UUID suitable for use as a correlation identifier.
    #
    # Creates a RFC 4122 compliant UUID using SecureRandom, providing a globally
    # unique identifier suitable for distributed request tracing.
    #
    # @return [String] a new UUID string in standard format (e.g., "123e4567-e89b-12d3-a456-426614174000")
    #
    # @example Generating correlation IDs
    #   id1 = CMDx::Correlator.generate  # => "018c2b95-b764-7615-a924-cc5b910ed1e5"
    #   id2 = CMDx::Correlator.generate  # => "018c2b95-b765-7123-b456-dd7c920fe3a8"
    #   id1 != id2  # => true
    def generate
      SecureRandom.uuid
    end

    ##
    # Retrieves the current thread's correlation identifier.
    #
    # Returns the correlation ID that was previously set for the current thread,
    # or nil if no correlation ID has been established. This method is thread-safe
    # and will not interfere with correlation IDs set in other threads.
    #
    # @return [String, nil] the current correlation ID or nil if none is set
    #
    # @example Checking current correlation
    #   CMDx::Correlator.id  # => nil (when none is set)
    #
    #   CMDx::Correlator.id = "test-correlation"
    #   CMDx::Correlator.id  # => "test-correlation"
    def id
      Thread.current[THREAD_KEY]
    end

    ##
    # Sets the correlation identifier for the current thread.
    #
    # Assigns a correlation ID to the current thread's local storage, making it
    # available for subsequent operations within the same thread context. The
    # correlation ID will persist until explicitly changed or cleared.
    #
    # @param value [String, #to_s] the correlation identifier to set
    # @return [String] the assigned correlation identifier
    #
    # @example Setting correlation ID
    #   CMDx::Correlator.id = "user-request-123"
    #   CMDx::Correlator.id  # => "user-request-123"
    #
    # @example Type coercion
    #   CMDx::Correlator.id = 12345
    #   CMDx::Correlator.id  # => 12345 (stored as provided)
    def id=(value)
      Thread.current[THREAD_KEY] = value
    end

    ##
    # Clears the correlation identifier for the current thread.
    #
    # Removes the correlation ID from the current thread's local storage,
    # effectively resetting the correlation context. Subsequent calls to
    # {#id} will return nil until a new correlation ID is set.
    #
    # @return [nil] always returns nil
    #
    # @example Clearing correlation
    #   CMDx::Correlator.id = "temporary-correlation"
    #   CMDx::Correlator.id  # => "temporary-correlation"
    #
    #   CMDx::Correlator.clear
    #   CMDx::Correlator.id  # => nil
    def clear
      Thread.current[THREAD_KEY] = nil
    end

    ##
    # Temporarily sets a correlation identifier for the duration of a block.
    #
    # Establishes a correlation context for the given block, automatically
    # restoring the previous correlation ID when the block completes. This
    # method is exception-safe and will restore the original context even
    # if the block raises an error.
    #
    # This is the preferred method for managing correlation contexts as it
    # ensures proper cleanup and supports nested correlation scopes.
    #
    # @param value [String, #to_s] the correlation identifier to use during block execution
    # @yieldreturn [Object] the return value of the block
    # @return [Object] the return value of the executed block
    #
    # @example Basic usage
    #   result = CMDx::Correlator.use("operation-123") do
    #     ProcessOrderTask.call(order_id: 456)
    #   end
    #   # Correlation context is automatically restored
    #
    # @example Nested contexts
    #   CMDx::Correlator.use("parent") do
    #     CMDx::Correlator.id  # => "parent"
    #
    #     CMDx::Correlator.use("child") do
    #       CMDx::Correlator.id  # => "child"
    #     end
    #
    #     CMDx::Correlator.id  # => "parent" (restored)
    #   end
    #
    # @example Exception safety
    #   CMDx::Correlator.id = "original"
    #
    #   begin
    #     CMDx::Correlator.use("temporary") do
    #       raise StandardError, "something went wrong"
    #     end
    #   rescue StandardError
    #     CMDx::Correlator.id  # => "original" (still restored)
    #   end
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
