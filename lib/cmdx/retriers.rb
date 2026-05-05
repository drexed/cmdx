# frozen_string_literal: true

module CMDx
  # Registry of named retry/jitter strategies used by `Retry` to compute the
  # sleep duration between attempts. Ships with built-ins for `:exponential`,
  # `:half_random`, `:full_random`, `:bounded_random`, `:linear`, `:fibonacci`,
  # and `:decorrelated_jitter`. A retrier is any callable accepting
  # `call(attempt, delay, prev_delay)` that returns the next delay in seconds.
  class Retriers

    attr_reader :registry

    def initialize
      @registry = {
        exponential: Retriers::Exponential,
        half_random: Retriers::HalfRandom,
        full_random: Retriers::FullRandom,
        bounded_random: Retriers::BoundedRandom,
        linear: Retriers::Linear,
        fibonacci: Retriers::Fibonacci,
        decorrelated_jitter: Retriers::DecorrelatedJitter
      }
    end

    # @param source [Retriers] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named retrier, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] retrier callable when `callable` is omitted
    # @yield retrier body — `call(attempt, delay, prev_delay)`
    # @return [Retriers] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved retrier isn't callable
    def register(name, callable = nil, &block)
      retrier = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !retrier.respond_to?(:call)
        raise ArgumentError, "retrier must respond to #call"
      end

      registry[name.to_sym] = retrier
      self
    end

    # @param name [Symbol]
    # @return [Retriers] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [Boolean] whether a retrier is registered under `name`
    def key?(name)
      registry.key?(name.to_sym)
    end

    # @param name [Symbol]
    # @return [#call] the registered retrier
    # @raise [ArgumentError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise ArgumentError, "unknown retrier: #{name.inspect}"
      end
    end

    # Resolves a `:jitter` spec to a concrete callable. Accepts a Symbol
    # (registry lookup) or any object responding to `#call`. `nil` resolves
    # to `nil` so callers can fall back to the unjittered base delay.
    #
    # @param spec [Symbol, #call, nil]
    # @return [#call, nil]
    # @raise [ArgumentError] when `spec` is an unknown symbol or not callable
    def resolve(spec)
      case spec
      when NilClass
        nil
      when Symbol
        lookup(spec)
      else
        return spec if spec.respond_to?(:call)

        raise ArgumentError, "unknown retrier: #{spec.inspect}"
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
