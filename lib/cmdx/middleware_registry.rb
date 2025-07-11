# frozen_string_literal: true

module CMDx
  # Registry for managing middleware definitions and execution within tasks.
  #
  # This registry handles the registration and execution of middleware that can
  # wrap task execution, providing cross-cutting concerns like logging, timing,
  # authentication, and error handling.
  class MiddlewareRegistry

    # The internal array storing middleware definitions.
    #
    # @return [Array] array containing middleware definition tuples
    attr_reader :registry

    # Initializes a new middleware registry.
    #
    # @param registry [Array] initial registry array with middleware definitions
    #
    # @return [MiddlewareRegistry] a new middleware registry instance
    #
    # @example Creating an empty registry
    #   MiddlewareRegistry.new
    #
    # @example Creating a registry with initial middleware
    #   MiddlewareRegistry.new([[LoggingMiddleware, [], nil]])
    def initialize(registry = [])
      @registry = registry.to_a
    end

    # Registers a middleware with optional arguments and block.
    #
    # @param middleware [Class, Object] the middleware class or instance to register
    # @param args [Array] arguments to pass to the middleware constructor
    # @param block [Proc] optional block to pass to the middleware constructor
    #
    # @return [MiddlewareRegistry] returns self for method chaining
    #
    # @example Registering a middleware class
    #   registry.register(LoggingMiddleware)
    #
    # @example Registering middleware with arguments
    #   registry.register(TimeoutMiddleware, 30)
    #
    # @example Registering middleware with a block
    #   registry.register(CustomMiddleware) { |task| puts "Processing #{task.name}" }
    def register(middleware, *args, &block)
      registry << [middleware, args, block]
      self
    end

    # Executes the middleware chain around the given task.
    #
    # @param task [Task] the task instance to execute with middleware
    # @param block [Proc] the block to execute after all middleware
    #
    # @return [Object] the result of the middleware chain execution
    #
    # @example Executing middleware chain
    #   registry.call(task) { |t| t.execute }
    #
    # @example Executing with empty registry
    #   registry.call(task) { |t| puts "No middleware" }
    def call(task, &)
      return yield(task) if registry.empty?

      build_chain(&).call(task)
    end

    # Returns an array representation of the registry.
    #
    # @return [Array] a deep copy of the registry array
    #
    # @example Getting registry contents
    #   registry.to_a
    #   # => [[LoggingMiddleware, [], nil], [TimeoutMiddleware, [30], nil]]
    def to_a
      registry.map(&:dup)
    end

    private

    # Builds the middleware chain by composing middleware in reverse order.
    #
    # @param block [Proc] the final block to execute after all middleware
    #
    # @return [Proc] a composed procedure that executes the middleware chain
    #
    # @example Building a chain (internal use)
    #   build_chain { |task| task.execute }
    def build_chain(&block)
      registry.reverse.reduce(block) do |next_callable, (middleware, args, middleware_block)|
        proc do |task|
          instance = middleware.respond_to?(:new) ? middleware.new(*args, &middleware_block) : middleware
          instance.call(task, next_callable)
        end
      end
    end

  end
end
