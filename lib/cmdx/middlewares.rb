# frozen_string_literal: true

module CMDx
  ##
  # The Middlewares collection provides a Rack-style middleware chain that wraps
  # task execution with cross-cutting concerns like logging, authentication,
  # caching, and more. Middleware can short-circuit execution by returning
  # early without calling the next middleware in the chain.
  #
  # The Middlewares collection extends Array to provide specialized functionality for
  # managing collections of middleware definitions within CMDx tasks. It handles
  # middleware execution coordination, chaining, and inspection.
  #
  # @example Basic middleware usage
  #   middlewares = Middlewares.new
  #   middlewares.use(LoggingMiddleware)
  #   middlewares.use(AuthenticationMiddleware, required_role: :admin)
  #   middlewares.use(CachingMiddleware, ttl: 300)
  #
  #   result = middlewares.call(task) do |t|
  #     t.call
  #     t.result
  #   end
  #
  # @example Array-like operations
  #   middlewares << [LoggingMiddleware, [], nil]
  #   middlewares.size  # => 1
  #   middlewares.empty?  # => false
  #   middlewares.each { |middleware| puts middleware.inspect }
  #
  # @example Using proc middleware
  #   middlewares.use(proc do |task, callable|
  #     puts "Before task execution"
  #     result = callable.call(task)
  #     puts "After task execution"
  #     result
  #   end)
  #
  # @see Middleware Base middleware class
  # @since 1.0.0
  class Middlewares < Array

    # Adds middleware to the registry.
    #
    # @param middleware [Class, Object, Proc] The middleware to add
    # @param args [Array] Arguments to pass to middleware constructor
    # @param block [Proc] Block to pass to middleware constructor
    # @return [Middlewares] self for method chaining
    #
    # @example Add middleware class
    #   registry.use(LoggingMiddleware, log_level: :info)
    #
    # @example Add middleware instance
    #   registry.use(LoggingMiddleware.new(log_level: :info))
    #
    # @example Add proc middleware
    #   registry.use(proc { |task, callable| callable.call(task) })
    def use(middleware, *args, &block)
      self << [middleware, args, block]
      self
    end

    # Executes the middleware chain around the given block.
    #
    # @param task [Task] The task instance to pass through middleware
    # @yield [Task] The task instance for final execution
    # @yieldreturn [Object] The result of task execution
    # @return [Object] The result from the middleware chain
    #
    # @example Execute with middleware
    #   result = registry.call(task) do |t|
    #     t.call
    #     t.result
    #   end
    def call(task, &)
      return yield(task) if empty?

      build_chain(&).call(task)
    end

    private

    # Builds the middleware call chain.
    #
    # Creates a nested chain of callables where each middleware wraps the next,
    # with the provided block as the innermost callable.
    #
    # @param block [Proc] The final block to execute
    # @return [Proc] The middleware chain as a callable
    def build_chain(&block)
      reverse.reduce(block) do |next_callable, (middleware, args, middleware_block)|
        proc do |task|
          if middleware.respond_to?(:call) && !middleware.respond_to?(:new)
            # Proc middleware
            middleware.call(task, next_callable)
          else
            # Class or instance middleware
            instance = middleware.respond_to?(:new) ? middleware.new(*args, &middleware_block) : middleware
            instance.call(task, next_callable)
          end
        end
      end
    end

  end
end
