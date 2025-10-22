# frozen_string_literal: true

module CMDx
  # Manages a collection of attributes for task definition and verification.
  # The registry provides methods to register, deregister, and process attributes
  # in a hierarchical structure, supporting nested attribute definitions.
  class AttributeRegistry

    # Returns the collection of registered attributes.
    #
    # @return [Array<Attribute>] Array of registered attributes
    #
    # @example
    #   registry.registry # => [#<Attribute @name=:name>, #<Attribute @name=:email>]
    #
    # @rbs @registry: Array[Attribute]
    attr_reader :registry
    alias to_a registry

    # Creates a new attribute registry with an optional initial collection.
    #
    # @param registry [Array<Attribute>] Initial attributes to register
    #
    # @return [AttributeRegistry] A new registry instance
    #
    # @example
    #   registry = AttributeRegistry.new
    #   registry = AttributeRegistry.new([attr1, attr2])
    #
    # @rbs (?Array[Attribute] registry) -> void
    def initialize(registry = [])
      @registry = registry
    end

    # Creates a duplicate of this registry with copied attributes.
    #
    # @return [AttributeRegistry] A new registry with duplicated attributes
    #
    # @example
    #   new_registry = registry.dup
    #
    # @rbs () -> AttributeRegistry
    def dup
      self.class.new(registry.dup)
    end

    # Registers one or more attributes to the registry.
    #
    # @param attributes [Attribute, Array<Attribute>] Attribute(s) to register
    #
    # @return [AttributeRegistry] Self for method chaining
    #
    # @example
    #   registry.register(attribute)
    #   registry.register([attr1, attr2])
    #
    # @rbs (Attribute | Array[Attribute] attributes) -> self
    def register(attributes)
      @registry.concat(Array(attributes))
      self
    end

    # Removes attributes from the registry by name.
    # Supports hierarchical attribute removal by matching the entire attribute tree.
    #
    # @param names [Symbol, String, Array<Symbol, String>] Name(s) of attributes to remove
    #
    # @return [AttributeRegistry] Self for method chaining
    #
    # @example
    #   registry.deregister(:name)
    #   registry.deregister(['name1', 'name2'])
    #
    # @rbs ((Symbol | String | Array[Symbol | String]) names) -> self
    def deregister(names)
      Array(names).each do |name|
        @registry.reject! { |attribute| matches_attribute_tree?(attribute, name.to_sym) }
      end

      self
    end

    # Associates all registered attributes with a task and verifies their definitions.
    # This method is called during task setup to establish attribute-task relationships
    # and validate the attribute hierarchy.
    #
    # @param task [Task] The task to associate with all attributes
    #
    # @rbs (Task task) -> void
    def define_and_verify(task)
      registry.each do |attribute|
        attribute.task = task
        attribute.define_and_verify_tree
      end
    end

    private

    # Recursively checks if an attribute or any of its children match the given name.
    #
    # @param attribute [Attribute] The attribute to check
    # @param name [Symbol] The name to match against
    #
    # @return [Boolean] True if the attribute or any child matches the name
    #
    # @rbs (Attribute attribute, Symbol name) -> bool
    def matches_attribute_tree?(attribute, name)
      return true if attribute.method_name == name

      attribute.children.any? { |child| matches_attribute_tree?(child, name) }
    end

  end
end
