# frozen_string_literal: true

module CMDx
  module Middlewares
    # Middleware for correlating task executions with unique identifiers.
    #
    # The Correlate middleware provides thread-safe correlation ID management
    # for tracking task execution flows across different operations.
    # It automatically generates correlation IDs when none are provided and
    # stores them in task result metadata for traceability.
    module Correlate

      extend self

      # @rbs THREAD_KEY: Symbol
      THREAD_KEY = :cmdx_correlate

      # Retrieves the current correlation ID from thread-local storage.
      #
      # @return [String, nil] The current correlation ID or nil if not set
      #
      # @example Get current correlation ID
      #   Correlate.id # => "550e8400-e29b-41d4-a716-446655440000"
      #
      # @rbs () -> String?
      def id
        Thread.current[THREAD_KEY]
      end

      # Sets the correlation ID in thread-local storage.
      #
      # @param id [String] The correlation ID to set
      # @return [String] The set correlation ID
      #
      # @example Set correlation ID
      #   Correlate.id = "abc-123-def"
      #
      # @rbs (String id) -> String
      def id=(id)
        Thread.current[THREAD_KEY] = id
      end

      # Clears the current correlation ID from thread-local storage.
      #
      # @return [nil] Always returns nil
      #
      # @example Clear correlation ID
      #   Correlate.clear
      #
      # @rbs () -> nil
      def clear
        Thread.current[THREAD_KEY] = nil
      end

      # Temporarily uses a new correlation ID for the duration of a block.
      # Restores the previous ID after the block completes, even if an error occurs.
      #
      # @param new_id [String] The correlation ID to use temporarily
      # @yield The block to execute with the new correlation ID
      # @return [Object] The result of the yielded block
      #
      # @example Use temporary correlation ID
      #   Correlate.use("temp-id") do
      #     # Operations here use "temp-id"
      #     perform_operation
      #   end
      #   # Previous ID is restored
      #
      # @rbs (String new_id) { () -> untyped } -> untyped
      def use(new_id)
        old_id = id
        self.id = new_id
        yield
      ensure
        self.id = old_id
      end

      # Middleware entry point that applies correlation ID logic to task execution.
      #
      # Evaluates the condition from options and applies correlation ID handling
      # if enabled. Generates or retrieves correlation IDs based on the :id option
      # and stores them in task result metadata.
      #
      # @param task [Task] The task being executed
      # @param options [Hash] Configuration options for correlation
      # @option options [Symbol, Proc, Object, nil] :id The correlation ID source
      # @option options [Symbol, Proc, Object, nil] :if Condition to enable correlation
      # @option options [Symbol, Proc, Object, nil] :unless Condition to disable correlation
      #
      # @yield The task execution block
      #
      # @return [Object] The result of task execution
      #
      # @example Basic usage with automatic ID generation
      #   Correlate.call(task, &block)
      # @example Use custom correlation ID
      #   Correlate.call(task, id: "custom-123", &block)
      # @example Use task method for ID
      #   Correlate.call(task, id: :correlation_id, &block)
      # @example Use proc for dynamic ID generation
      #   Correlate.call(task, id: -> { "dynamic-#{Time.now.to_i}" }, &block)
      # @example Conditional correlation
      #   Correlate.call(task, if: :enable_correlation, &block)
      #
      # @rbs (Task task, **untyped options) { () -> untyped } -> untyped
      def call(task, **options, &)
        return yield unless Utils::Condition.evaluate(task, options)

        correlation_id = task.result.metadata[:correlation_id] ||=
          id ||
          case callable = options[:id]
          when Symbol then task.send(callable)
          when Proc then task.instance_eval(&callable)
          else
            if callable.respond_to?(:call)
              callable.call(task)
            else
              callable || id || Identifier.generate
            end
          end

        use(correlation_id, &)
      end

    end
  end
end
