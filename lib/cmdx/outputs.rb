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

    # Declares one or more output keys. All share the same `options`. A block
    # nests child outputs under each declared key (see {ChildBuilder}).
    #
    # @param keys [Array<Symbol>]
    # @param options [Hash{Symbol => Object}] passed through to {Output#initialize}
    # @yield block evaluated in a {ChildBuilder} for nested outputs
    # @return [Outputs] self for chaining
    def register(*keys, **options, &block)
      children = block ? ChildBuilder.build(&block) : EMPTY_ARRAY

      keys.each do |key|
        output = Output.new(key, children:, **options)
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

    # DSL receiver for the block passed to {Outputs#register}. Builds a frozen
    # list of child {Output}s. Supports arbitrary nesting: every DSL method
    # accepts its own block.
    class ChildBuilder

      class << self

        # @yield (see Outputs#register)
        # @return [Array<Output>] frozen list of built children
        def build(&)
          builder = new
          builder.instance_eval(&)
          builder.children.freeze
        end

      end

      attr_reader :children

      def initialize
        @children = []
      end

      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}]
      # @return [Array<Output>]
      def outputs(*names, **options, &)
        build(*names, **options, &)
      end
      alias output outputs

      # Declares optional child outputs (equivalent to `outputs ..., required: false`).
      def optional(*names, **options, &)
        build(*names, required: false, **options, &)
      end

      # Declares required child outputs (equivalent to `outputs ..., required: true`).
      def required(*names, **options, &)
        build(*names, required: true, **options, &)
      end

      private

      def build(*names, **options, &block)
        nested = block ? self.class.build(&block) : EMPTY_ARRAY
        names.map { |name| children << Output.new(name, children: nested, **options) }
      end

    end

  end
end
