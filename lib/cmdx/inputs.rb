# frozen_string_literal: true

module CMDx
  # Registry of declared task inputs. Each registration creates an {Input} and
  # defines a reader method on the task class. {#resolve} walks every input
  # (and nested children) to populate the task's instance variables before `work`.
  class Inputs

    attr_reader :registry

    def initialize
      @registry = {}
    end

    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Declares one or more inputs and defines accessor readers on `klass`.
    # A block nests child inputs under each declared name (see {ChildBuilder}).
    #
    # @param klass [Class] the task class to define readers on
    # @param names [Array<Symbol>] input names
    # @param options [Hash{Symbol => Object}] passed to {Input#initialize}
    # @yield block evaluated in a {ChildBuilder} for nested inputs
    # @return [Inputs] self for chaining
    def register(klass, *names, **options, &block)
      children = block ? ChildBuilder.build(&block) : EMPTY_ARRAY

      names.each do |name|
        input = Input.new(name, children:, **options)
        registry[input.name] = input
        klass.send(:define_input_reader, input)
      end

      self
    end

    # Removes inputs and their accessor readers from `klass`.
    #
    # @param klass [Class]
    # @param names [Array<Symbol>]
    # @return [Inputs] self for chaining
    def deregister(klass, *names)
      names.each do |name|
        input = registry.delete(name.to_sym)
        klass.send(:undefine_input_reader, input)
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

    # Resolves every input (with children) for `task`, setting each input's
    # computed value into its backing ivar so the generated readers return it.
    #
    # @param task [Task]
    # @return [void]
    def resolve(task)
      registry.each_value do |input|
        value = input.resolve(task)
        task.instance_variable_set(input.ivar_name, value)
        resolve_children(input, value, task)
      end
    end

    private

    def resolve_children(input, parent_value, task)
      return if input.children.empty? || parent_value.nil?

      input.children.each do |child|
        child_value = child.resolve_from_parent(parent_value, task)
        task.instance_variable_set(child.ivar_name, child_value)
        resolve_children(child, child_value, task)
      end
    end

    # DSL receiver for the block passed to {Inputs#register}. Builds a frozen
    # list of child {Input}s. Supports arbitrary nesting: every DSL method
    # accepts its own block.
    class ChildBuilder

      class << self

        # @yield (see Inputs#register)
        # @return [Array<Input>] frozen list of built children
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
      # @return [Array<Input>]
      def inputs(*names, **options, &)
        build(*names, **options, &)
      end
      alias input inputs

      # Declares optional child inputs (equivalent to `inputs ..., required: false`).
      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}]
      # @return [Array<Input>]
      def optional(*names, **options, &)
        build(*names, required: false, **options, &)
      end

      # Declares required child inputs (equivalent to `inputs ..., required: true`).
      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}]
      # @return [Array<Input>]
      def required(*names, **options, &)
        build(*names, required: true, **options, &)
      end

      private

      def build(*names, **options, &block)
        nested = block ? self.class.build(&block) : EMPTY_ARRAY
        names.map { |name| children << Input.new(name, children: nested, **options) }
      end

    end

  end
end
