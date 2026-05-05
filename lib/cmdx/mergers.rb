# frozen_string_literal: true

module CMDx
  # Registry of named merge strategies used to fold successful parallel task
  # results back into the workflow context. Ships with built-ins for
  # `:last_write_wins` (default), `:deep_merge`, and `:no_merge`. A merger is
  # any callable accepting `call(workflow_context, result)`.
  class Mergers

    attr_reader :registry

    def initialize
      @registry = {
        last_write_wins: Mergers::LastWriteWins,
        deep_merge: Mergers::DeepMerge,
        no_merge: Mergers::NoMerge
      }
    end

    # @param source [Mergers] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named merger, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] merger callable when `callable` is omitted
    # @yield merger body — `call(workflow_context, result)`
    # @return [Mergers] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved merger isn't callable
    def register(name, callable = nil, &block)
      merger = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !merger.respond_to?(:call)
        raise ArgumentError, "merger must respond to #call"
      end

      registry[name.to_sym] = merger
      self
    end

    # @param name [Symbol]
    # @return [Mergers] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [#call] the registered merger
    # @raise [ArgumentError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise ArgumentError, "unknown merger: #{name.inspect}"
      end
    end

    # Resolves a declaration's `:merger` option to a concrete
    # callable. Accepts `nil` (default `:last_write_wins`), a Symbol
    # (registry lookup), or any object responding to `#call`.
    #
    # @param spec [Symbol, #call, nil]
    # @return [#call]
    # @raise [ArgumentError] when `spec` is an unknown symbol or not callable
    def resolve(spec)
      case spec
      when NilClass
        lookup(:last_write_wins)
      when Symbol
        lookup(spec)
      else
        return spec if spec.respond_to?(:call)

        raise ArgumentError, "unknown merger: #{spec.inspect}"
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
