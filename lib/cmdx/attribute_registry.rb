# frozen_string_literal: true

module CMDx
  # Registry of attribute definitions for a task class.
  # Manages attribute reader modules and COW semantics for inheritance.
  class AttributeRegistry

    # @rbs @definitions: Hash[Symbol, Attribute]
    # @rbs @reader_module: Module?
    attr_reader :definitions

    # @rbs (?Hash[Symbol, Attribute]? definitions) -> void
    def initialize(definitions = nil)
      @definitions = definitions || {}
      @reader_module = nil
    end

    # Registers an attribute definition.
    #
    # @param attribute [Attribute] the attribute to register
    #
    # @rbs (Attribute attribute) -> void
    def register(attribute)
      definitions[attribute.name] = attribute
    end

    # Removes an attribute definition.
    #
    # @param name [Symbol] the attribute name
    #
    # @rbs (Symbol name) -> void
    def deregister(name)
      definitions.delete(name.to_sym)
    end

    # Looks up an attribute by name.
    #
    # @param name [Symbol] the attribute name
    #
    # @return [Attribute, nil]
    #
    # @rbs (Symbol name) -> Attribute?
    def [](name)
      definitions[name.to_sym]
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def any?
      !definitions.empty?
    end

    # @return [Integer]
    #
    # @rbs () -> Integer
    def size
      definitions.size
    end

    # @rbs () { (Symbol, Attribute) -> void } -> void
    def each(&)
      definitions.each(&)
    end

    # Builds the reader module for the task class and includes it.
    # This creates accessor methods for all attributes on an anonymous module.
    #
    # @param task_class [Class] the task class to include the module into
    #
    # @rbs (untyped task_class) -> void
    def define_readers!(task_class)
      return if definitions.empty?

      mod = Module.new
      definitions.each_value do |attr|
        alloc_name = attr.allocation_name
        next unless alloc_name

        mod.define_method(alloc_name) { @_attributes[alloc_name] }
      end
      task_class.include(mod)
      @reader_module = mod
    end

    # Resolves all attribute values from the given context into a hash.
    #
    # @param task [Task] the task instance
    # @param context [Context] the execution context
    # @param errors [Errors] the error collection
    #
    # @return [Hash{Symbol => Object}] resolved attribute values
    #
    # @rbs (untyped task, Context context, Errors errors) -> Hash[Symbol, untyped]
    def resolve(task, context, errors)
      definitions.each_with_object({}) do |(_name, attr), resolved|
        value = ValueResolver.call(attr, task, context)
        resolved[attr.allocation_name || attr.name] = value

        attr.validations.each do |type, options|
          validator = ValidatorRegistry.new.resolve(type)
          opts = options.is_a?(Hash) ? options : {}
          message = validator.call(value, **opts)
          errors.add(attr.name, message) if message
        end
      end
    end

    # Returns a schema representation of all attributes.
    #
    # @return [Hash{Symbol => Hash}]
    #
    # @rbs () -> Hash[Symbol, Hash[Symbol, untyped]]
    def schema
      definitions.transform_values(&:to_h)
    end

    # @return [AttributeRegistry] a duplicated registry for child classes
    #
    # @rbs () -> AttributeRegistry
    def for_child
      duped = definitions.transform_values(&:dup)
      self.class.new(duped)
    end

  end
end
