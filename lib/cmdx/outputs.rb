# frozen_string_literal: true

module CMDx
  # Registry of declared task outputs. Runtime verifies each output after
  # `work` completes: presence, coercion, and validation run against values
  # the task wrote to context.
  class Outputs

    attr_reader :registry

    def initialize
      @registry = {}
    end

    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Declares one or more output keys. All share the same `options`.
    #
    # @param keys [Array<Symbol>]
    # @param options [Hash{Symbol => Object}] passed through to {Output#initialize}
    # @return [Outputs] self for chaining
    def register(*keys, **options)
      keys.each do |key|
        output = Output.new(key, **options)
        registry[output.name] = output
      end

      self
    end

    # @param keys [Array<Symbol>]
    # @return [Outputs] self for chaining
    def deregister(*keys)
      keys.each { |key| registry.delete(key.to_sym) }
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

    # Verifies every declared output against `task.context`. Adds any failures
    # to `task.errors`.
    #
    # @param task [Task]
    # @return [void]
    def verify(task)
      registry.each_value { |output| output.verify(task) }
    end

  end
end
