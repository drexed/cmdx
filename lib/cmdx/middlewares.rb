# frozen_string_literal: true

module CMDx
  # Ordered list of middlewares wrapping a task's lifecycle. Each middleware
  # is a callable with the signature `call(task) { next_link.call }`; Runtime
  # builds a nested chain and requires each middleware to yield to the next.
  class Middlewares

    attr_reader :registry

    def initialize
      @registry = []
    end

    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Inserts a middleware. With no `:at`, appends. With `:at`, inserts at
    # the given (clamped) index — supports negative indexing.
    #
    # @param callable [#call, nil] provide either this or a block
    # @param at [Integer, nil] insertion index
    # @yield the middleware body, receiving `(task)` and `next_link` via block
    # @return [Middlewares] self for chaining
    # @raise [ArgumentError] when both or neither of `callable`/block are given,
    #   when the callable doesn't respond to `#call`, or when `:at` isn't an Integer
    def register(callable = nil, at: nil, &block)
      middleware = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !middleware.respond_to?(:call)
        raise ArgumentError, "middleware must respond to #call"
      elsif !at.nil? && !at.is_a?(Integer)
        raise ArgumentError, "at must be an Integer"
      end

      if at.nil?
        registry << middleware
      else
        at = [at.clamp(-registry.size - 1, registry.size), registry.size].min
        registry.insert(at, middleware)
      end

      self
    end

    # Removes a middleware by reference or by index.
    #
    # @param middleware [#call, nil] the exact middleware to remove
    # @param at [Integer, nil] index to remove
    # @return [Middlewares] self for chaining
    # @raise [ArgumentError] when neither or both of `middleware`/`:at` are given,
    #   or when `:at` isn't an Integer
    def deregister(middleware = nil, at: nil)
      if at.nil? && middleware.nil?
        raise ArgumentError, "provide either a middleware or an at: index"
      elsif !at.nil? && !middleware.nil?
        raise ArgumentError, "provide either a middleware or an at: index, not both"
      elsif !at.nil? && !at.is_a?(Integer)
        raise ArgumentError, "at must be an Integer"
      end

      if at.nil?
        registry.delete(middleware)
      else
        registry.delete_at(at)
      end

      self
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer]
    def size
      registry.size
    end

    # Walks the middleware chain around `task`'s lifecycle. The final link
    # yields to `block`, which is expected to run the actual lifecycle.
    #
    # @param task [Task]
    # @yield the innermost link — the task's lifecycle body
    # @return [void]
    # @raise [MiddlewareError] when a middleware forgets to yield to `next_link`,
    #   which would otherwise silently skip the task
    def process(task)
      processed = false
      count = registry.size

      chain = lambda do |i|
        if i == count
          processed = true
          yield
        else
          registry[i].call(task) { chain.call(i + 1) }
        end
      end
      chain.call(0)

      processed || begin
        raise MiddlewareError, "middleware did not yield the next_link"
      end
    end

  end
end
