# frozen_string_literal: true

module CMDx
  # Registry of named deprecation actions consulted by `Deprecation#execute`
  # to dispatch a task class's deprecation. Ships with built-ins for
  # `:log`, `:warn`, and `:error`. A deprecator is any callable accepting
  # `call(task)`; the return value is discarded.
  class Deprecators

    attr_reader :registry

    def initialize
      @registry = {
        log: Deprecators::Log,
        warn: Deprecators::Warn,
        error: Deprecators::Error
      }
    end

    # @param source [Deprecators] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named deprecator, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] deprecator callable when `callable` is omitted
    # @yield deprecator body — `call(task)`
    # @return [Deprecators] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved deprecator isn't callable
    def register(name, callable = nil, &block)
      deprecator = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !deprecator.respond_to?(:call)
        raise ArgumentError, "deprecator must respond to #call"
      end

      registry[name.to_sym] = deprecator
      self
    end

    # @param name [Symbol]
    # @return [Deprecators] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [Boolean] whether a deprecator is registered under `name`
    def key?(name)
      registry.key?(name.to_sym)
    end

    # @param name [Symbol]
    # @return [#call] the registered deprecator
    # @raise [ArgumentError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise ArgumentError, "unknown deprecator: #{name.inspect}"
      end
    end

    # Resolves a `deprecation` declaration's value to a concrete callable.
    # Accepts a Symbol (registry lookup) or any object responding to `#call`.
    # `nil` resolves to `nil` so callers can short-circuit.
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

        raise ArgumentError, "unknown deprecator: #{spec.inspect}"
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
