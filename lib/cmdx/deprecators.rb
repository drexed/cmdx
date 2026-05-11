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
        raise ArgumentError, "deprecator: provide either a callable or a block, not both"
      elsif !deprecator.respond_to?(:call)
        raise ArgumentError,
          "deprecator must respond to #call (got #{deprecator.class}). " \
          "See https://drexed.github.io/cmdx/deprecation/"
      end

      registry[name.to_sym] = deprecator
      self
    end

    # @param name [Symbol]
    # @return [Deprecators] self for chaining
    def deregister(name)
      registry.delete(name)
      self
    end

    # @param name [Symbol]
    # @return [Boolean] whether a deprecator is registered under `name`
    def key?(name)
      registry.key?(name)
    end

    # @param name [Symbol]
    # @return [#call] the registered deprecator
    # @raise [UnknownEntryError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise UnknownEntryError,
          "unknown deprecator #{name.inspect}; registered: #{registry.keys.inspect}. " \
          "See https://drexed.github.io/cmdx/deprecation/"
      end
    end

    # Resolves a `deprecation` declaration's value to a concrete callable.
    # Accepts a Symbol (registry lookup) or any object responding to `#call`.
    # `nil` resolves to `nil` so callers can short-circuit.
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

        raise UnknownEntryError,
          "unknown deprecator #{spec.inspect}; expected a Symbol from #{registry.keys.inspect} or a callable. " \
          "See https://drexed.github.io/cmdx/deprecation/"
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
