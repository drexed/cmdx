# frozen_string_literal: true

module CMDx
  # Registry of named rate-limit strategies used by {RateLimit}. Ships with
  # `:fixed_window` and `:leaky_bucket`. A limiter is any callable accepting
  # a {RateLimit::Quota} and returning a {RateLimit::Admission}.
  class Limiters

    attr_reader :registry

    def initialize
      @registry = {
        fixed_window: Limiters::FixedWindow,
        leaky_bucket: Limiters::LeakyBucket
      }
    end

    # @param source [Limiters] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named limiter, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] limiter callable when `callable` is omitted
    # @yieldparam quota [RateLimit::Quota]
    # @yieldreturn [RateLimit::Admission]
    # @return [Limiters] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved limiter isn't callable
    def register(name, callable = nil, &block)
      limiter = callable || block

      if callable && block
        raise ArgumentError, "limiter: provide either a callable or a block, not both"
      elsif !limiter.respond_to?(:call)
        raise ArgumentError, <<~MSG.chomp
          limiter must respond to #call (got #{limiter.class}).
          See https://drexed.github.io/cmdx/rate_limit/#custom-limiters-via-the-limiters-registry
        MSG
      end

      registry[name.to_sym] = limiter
      self
    end

    # @param name [Symbol]
    # @return [Limiters] self for chaining
    def deregister(name)
      registry.delete(name)
      self
    end

    # @param name [Symbol]
    # @return [Boolean] whether a limiter is registered under `name`
    def key?(name)
      registry.key?(name)
    end

    # @param name [Symbol]
    # @return [#call] the registered limiter
    # @raise [UnknownEntryError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise UnknownEntryError, <<~MSG.chomp
          unknown limiter #{name.inspect}; registered: #{registry.keys.inspect}.
          See https://drexed.github.io/cmdx/rate_limit/#built-in-limiters
        MSG
      end
    end

    # Resolves a `:limiter` spec to a concrete callable.
    #
    # @param spec [Symbol, #call, nil]
    # @return [#call, nil]
    # @raise [UnknownEntryError] when `spec` is an unknown symbol or not callable
    def resolve(spec)
      case spec
      when NilClass
        nil
      when Symbol
        lookup(spec)
      else
        return spec if spec.respond_to?(:call)

        raise UnknownEntryError, <<~MSG.chomp
          unknown limiter #{spec.inspect}; expected a Symbol from #{registry.keys.inspect} or a callable.
          See https://drexed.github.io/cmdx/rate_limit/#built-in-limiters
        MSG
      end
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer]
    def size
      registry.size
    end

  end
end
