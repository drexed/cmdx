# frozen_string_literal: true

module CMDx
  # Registry for managing middleware components in a task execution chain.
  #
  # The MiddlewareRegistry maintains an ordered list of middleware components
  # that can be inserted, removed, and executed in sequence. Each middleware
  # can be configured with specific options and is executed in the order
  # they were registered.
  class MiddlewareRegistry

    attr_reader :registry
    alias to_a registry

    # Initialize a new middleware registry.
    #
    # @param registry [Array] Initial array of middleware entries
    #
    # @example
    #   registry = MiddlewareRegistry.new
    #   registry = MiddlewareRegistry.new([[MyMiddleware, {option: 'value'}]])
    def initialize(registry = [])
      @registry = registry
    end

    # Create a duplicate of the registry with duplicated middleware entries.
    #
    # @return [MiddlewareRegistry] A new registry instance with duplicated entries
    #
    # @example
    #   new_registry = registry.dup
    def dup
      self.class.new(registry.map(&:dup))
    end

    # Register a middleware component in the registry.
    #
    # @param middleware [Object] The middleware object to register
    # @param at [Integer] Position to insert the middleware (default: -1, end of list)
    # @param options [Hash] Configuration options for the middleware
    # @option options [Symbol] :key Configuration key for the middleware
    # @option options [Object] :value Configuration value for the middleware
    #
    # @return [MiddlewareRegistry] Returns self for method chaining
    #
    # @example
    #   registry.register(LoggingMiddleware, at: 0, log_level: :debug)
    #   registry.register(AuthMiddleware, at: -1, timeout: 30)
    def register(middleware, at: -1, **options)
      registry.insert(at, [middleware, options])
      self
    end

    # Remove a middleware component from the registry.
    #
    # @param middleware [Object] The middleware object to remove
    #
    # @return [MiddlewareRegistry] Returns self for method chaining
    #
    # @example
    #   registry.deregister(LoggingMiddleware)
    def deregister(middleware)
      registry.reject! { |mw, _opts| mw == middleware }
      self
    end

    # Execute the middleware chain for a given task.
    #
    # @param task [Object] The task object to process through middleware
    #
    # @yield [task] Block to execute after all middleware processing
    # @yieldparam task [Object] The processed task object
    #
    # @return [Object] Result of the block execution
    #
    # @raise [ArgumentError] When no block is provided
    #
    # @example
    #   result = registry.call!(my_task) do |processed_task|
    #     processed_task.execute
    #   end
    def call!(task, &)
      raise ArgumentError, "block required" unless block_given?

      recursively_call_middleware(0, task, &)
    end

    private

    # Recursively execute middleware in the chain.
    #
    # @param index [Integer] Current middleware index in the chain
    # @param task [Object] The task object being processed
    #
    # @yield [task] Block to execute after middleware processing
    # @yieldparam task [Object] The processed task object
    #
    # @return [Object] Result of the block execution or next middleware call
    def recursively_call_middleware(index, task, &block)
      return yield(task) if index >= registry.size

      middleware, options = registry[index]
      middleware.call(task, **options) { recursively_call_middleware(index + 1, task, &block) }
    end

  end
end
