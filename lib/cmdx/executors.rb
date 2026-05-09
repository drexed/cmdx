# frozen_string_literal: true

module CMDx
  # Registry of named executors used by `:parallel` workflow groups to
  # dispatch tasks concurrently. Ships with built-ins for `:threads` and
  # `:fibers`. Executors are any callable accepting
  # `call(jobs:, concurrency:, on_job:)` and must invoke `on_job.call(job)`
  # for each job, blocking until every job is done.
  class Executors

    attr_reader :registry

    def initialize
      @registry = {
        threads: Executors::Thread,
        fibers: Executors::Fiber
      }
    end

    # @param source [Executors] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named executor, overwriting any existing entry.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @param block [#call, nil] executor callable when `callable` is omitted
    # @yield executor body — `call(jobs:, concurrency:, on_job:)`
    # @return [Executors] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved executor isn't callable
    def register(name, callable = nil, &block)
      executor = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !executor.respond_to?(:call)
        raise ArgumentError, "executor must respond to #call"
      end

      registry[name.to_sym] = executor
      self
    end

    # @param name [Symbol]
    # @return [Executors] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [#call] the registered executor
    # @raise [UnknownEntryError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise UnknownEntryError, "unknown executor: #{name.inspect}"
      end
    end

    # Resolves a declaration's `:executor` option to a concrete callable.
    # Accepts `nil` (default `:threads`), a Symbol (registry lookup), or any
    # object responding to `#call`.
    #
    # @param spec [Symbol, #call, nil]
    # @return [#call]
    # @raise [UnknownEntryError] when `spec` is an unknown symbol or not callable
    def resolve(spec)
      case spec
      when NilClass
        lookup(:threads)
      when Symbol
        lookup(spec)
      else
        return spec if spec.respond_to?(:call)

        raise UnknownEntryError, "unknown executor: #{spec.inspect}"
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
