# frozen_string_literal: true

module CMDx
  # Ordered collection of Attribute objects. Managed at the class level on Task,
  # inherited via the `inherited` hook with deep duplication.
  class AttributeSet

    def initialize
      @attributes = {}
    end

    def initialize_copy(source)
      super
      @attributes = source.instance_variable_get(:@attributes).transform_values do |attr|
        Attribute.new(attr.name, attr.options.dup,
                      children: attr.children&.dup)
      end
    end

    # Define one or more attributes.
    #
    # @param names [Array<Symbol>]
    # @param options [Hash]
    # @param block [Proc] for nesting child attributes
    # @return [void]
    def define(*names, **options, &block)
      names.each do |name|
        sym = name.to_sym

        raise ArgumentError, Messages.resolve("attribute.reserved") if Attribute::RESERVED_NAMES.include?(sym)

        children = nil
        if block
          children = AttributeSet.new
          children.instance_eval(&block)
        end

        @attributes[sym] = Attribute.new(sym, options, children: children)
      end
    end

    # Remove an attribute and its children.
    #
    # @param name [Symbol]
    # @return [void]
    def remove(name)
      @attributes.delete(name.to_sym)
    end

    # @return [Integer]
    def size
      @attributes.size
    end

    # @return [Boolean]
    def empty?
      @attributes.empty?
    end

    # @param name [Symbol]
    # @return [CMDx::Attribute, nil]
    def [](name)
      @attributes[name.to_sym]
    end

    # Iterate over attributes in definition order.
    # @yield [CMDx::Attribute]
    def each_attribute(&)
      @attributes.each_value(&)
    end

    # Process all attributes for a task, returning processed values and errors.
    #
    # @param task [CMDx::Task]
    # @param task_coercions [Hash, nil]
    # @param task_validators [Hash, nil]
    # @return [Hash<Symbol, Object>] processed attribute values
    def process(task, task_coercions: nil, task_validators: nil)
      values = {}
      error_set = task.errors

      each_attribute do |attr|
        values[attr.name] = attr.process(task, error_set,
                                         task_coercions: task_coercions,
                                         task_validators: task_validators)
      end

      values
    end

    # @return [Hash] full attribute schema for introspection
    def schema
      @attributes.transform_values(&:to_schema)
    end

    # Define accessor methods on the target class for all attributes.
    #
    # @param klass [Class]
    # @return [void]
    def define_accessors(klass)
      each_attribute do |attr|
        method_name = attr.accessor_name
        attr_name = attr.name

        klass.define_method(method_name) { @__attributes__[attr_name] } unless klass.method_defined?(method_name)
      end
    end

  end
end
