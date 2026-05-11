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

    # @param source [Middlewares] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Inserts a middleware. With no `:at`, appends. With `:at`, inserts at
    # the given (clamped) index — supports negative indexing. `:if`/`:unless`
    # gates evaluated against the task at process time.
    #
    # @param callable [#call, nil] provide either this or a block
    # @param block [#call, nil] middleware callable when `callable` is omitted
    # @param options [Hash{Symbol => Object}]
    # @option options [Symbol, Proc, #call] :if   gate that must evaluate truthy
    # @option options [Symbol, Proc, #call] :unless gate that must evaluate falsy
    # @option options [Integer] :at insertion index (see implementation)
    # @return [Middlewares] self for chaining
    # @raise [ArgumentError] when both or neither of `callable`/block are given,
    #   when the callable doesn't respond to `#call`, or when `:at` isn't an Integer
    # @yield the middleware body, receiving `(task)` and `next_link` via block
    def register(callable = nil, **options, &block)
      middleware = callable || block
      at = options.delete(:at)

      if callable && block
        raise ArgumentError, "middleware: provide either a callable or a block, not both"
      elsif !middleware.respond_to?(:call)
        raise ArgumentError,
          "middleware must respond to #call (got #{middleware.class}). " \
          "See https://drexed.github.io/cmdx/middlewares/"
      elsif !at.nil? && !at.is_a?(Integer)
        raise ArgumentError, "middleware :at must be an Integer (got #{at.class})"
      end

      entry = [middleware, options.freeze]

      if at.nil?
        registry << entry
      else
        at = [at.clamp(-registry.size - 1, registry.size), registry.size].min
        registry.insert(at, entry)
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
        raise ArgumentError, "middleware: provide either a middleware or an at: index"
      elsif !at.nil? && !middleware.nil?
        raise ArgumentError, "middleware: provide either a middleware or an at: index, not both"
      elsif !at.nil? && !at.is_a?(Integer)
        raise ArgumentError, "middleware :at must be an Integer (got #{at.class})"
      end

      if at.nil?
        registry.reject! { |mw, _opts| mw == middleware }
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
      last_invoked = nil
      count = registry.size

      chain = lambda do |i|
        if i == count
          processed = true
          yield
        else
          mw, opts = registry[i]

          if Util.satisfied?(opts[:if], opts[:unless], task)
            last_invoked = mw
            mw.call(task) { chain.call(i + 1) }
          else
            chain.call(i + 1)
          end
        end
      end
      chain.call(0)

      processed || begin
        offender = last_invoked.is_a?(Class) ? last_invoked : last_invoked.class
        raise MiddlewareError,
          "middleware #{offender} did not yield to next_link. " \
          "See https://drexed.github.io/cmdx/middlewares/"
      end
    end

  end
end
