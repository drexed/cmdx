# frozen_string_literal: true

module CMDx
  # Registry for managing middleware definitions and execution within tasks.
  #
  # This registry handles the registration and execution of middleware that can
  # wrap task execution, providing cross-cutting concerns like logging, timing,
  # authentication, and error handling.
  class MiddlewareRegistry

    # The internal hash storing middleware definitions and their configurations.
    #
    # @return [Hash] hash containing middleware classes/objects and their configurations
    attr_reader :registry

    # Initializes a new middleware registry.
    #
    # @param registry [Hash] optional hash of initial middleware configurations
    #
    # @return [MiddlewareRegistry] a new middleware registry instance
    #
    # @example Creating an empty registry
    #   MiddlewareRegistry.new
    #
    # @example Creating a registry with initial middleware
    #   MiddlewareRegistry.new(TimeoutMiddleware => [[], {timeout: 30}, nil])
    def initialize(registry = {})
      @registry = registry.to_h
    end

    # Registers a middleware with the registry.
    #
    # @param middleware [Class, Object] the middleware class or instance to register
    # @param args [Array] positional arguments to pass to middleware initialization
    # @param kwargs [Hash] keyword arguments to pass to middleware initialization
    # @param block [Proc] optional block to pass to middleware initialization
    #
    # @return [MiddlewareRegistry] self for method chaining
    #
    # @example Register a middleware class
    #   registry.register(TimeoutMiddleware, 30)
    #
    # @example Register a middleware with keyword arguments
    #   registry.register(LoggingMiddleware, level: :info)
    #
    # @example Register a middleware with a block
    #   registry.register(CustomMiddleware) { |task| puts "Processing #{task.id}" }
    def register(middleware, *args, **kwargs, &block)
      registry[middleware] = [args, kwargs, block]
      self
    end

    # Executes all registered middleware around the provided task.
    #
    # @param task [Task] the task instance to execute middleware around
    # @param block [Proc] the block to execute after all middleware processing
    #
    # @return [Object] the result of the middleware chain execution
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Execute middleware around a task
    #   registry.call(task) { |task| task.process }
    #
    # @example Execute with early return if no middleware
    #   registry.call(task) { |task| puts "No middleware to execute" }
    def call(task, &)
      raise ArgumentError, "block required" unless block_given?

      return yield(task) if registry.empty?

      build_chain(&).call(task)
    end

    # Returns a hash representation of the registry.
    #
    # @return [Hash] deep copy of registry with duplicated configuration arrays
    # @option return [Array] args duplicated positional arguments array
    # @option return [Hash] kwargs duplicated keyword arguments hash
    # @option return [Proc, nil] block the original block reference (not duplicated)
    #
    # @example Getting registry hash
    #   registry.to_h
    #   #=> { TimeoutMiddleware => [[30], {}, nil] }
    def to_h
      registry.transform_values do |config|
        args, kwargs, block = config
        [args.dup, kwargs.dup, block]
      end
    end

    private

    # Builds the middleware execution chain by wrapping middleware around the call block.
    #
    # @param call_block [Proc] the final block to execute after all middleware
    #
    # @return [Proc] the complete middleware chain as a callable proc
    #
    # @example Building a middleware chain (internal use)
    #   build_chain { |task| task.process }
    def build_chain(&call_block)
      registry.reverse_each.reduce(call_block) do |next_callable, (middleware, config)|
        proc do |task|
          args, kwargs, block = config
          instance = middleware.respond_to?(:new) ? middleware.new(*args, **kwargs, &block) : middleware
          instance.call(task, next_callable)
        end
      end
    end

  end
end
