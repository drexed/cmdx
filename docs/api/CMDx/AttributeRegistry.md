# Class: CMDx::AttributeRegistry
**Inherits:** Object
    

Manages a collection of attributes for task definition and verification. The
registry provides methods to register, deregister, and process attributes in a
hierarchical structure, supporting nested attribute definitions.


# Attributes
## registry[RW] [](#attribute-i-registry)
Returns the collection of registered attributes.

**@return** [Array<Attribute>] Array of registered attributes


**@example**
```ruby
registry.registry # => [#<Attribute @name=:name>, #<Attribute @name=:email>]
```
# Instance Methods
## define_and_verify(task) [](#method-i-define_and_verify)
Associates all registered attributes with a task and verifies their
definitions. This method is called during task setup to establish
attribute-task relationships and validate the attribute hierarchy.

**@param** [Task] The task to associate with all attributes

## deregister(names) [](#method-i-deregister)
Removes attributes from the registry by name. Supports hierarchical attribute
removal by matching the entire attribute tree.

**@param** [Symbol, String, Array<Symbol, String>] Name(s) of attributes to remove

**@return** [AttributeRegistry] Self for method chaining


**@example**
```ruby
registry.deregister(:name)
registry.deregister(['name1', 'name2'])
```## dup() [](#method-i-dup)
Creates a duplicate of this registry with copied attributes.

**@return** [AttributeRegistry] A new registry with duplicated attributes


**@example**
```ruby
new_registry = registry.dup
```## initialize(registry[]) [](#method-i-initialize)
Creates a new attribute registry with an optional initial collection.

**@param** [Array<Attribute>] Initial attributes to register

**@return** [AttributeRegistry] A new registry instance


**@example**
```ruby
registry = AttributeRegistry.new
registry = AttributeRegistry.new([attr1, attr2])
```## register(attributes) [](#method-i-register)
Registers one or more attributes to the registry.

**@param** [Attribute, Array<Attribute>] Attribute(s) to register

**@return** [AttributeRegistry] Self for method chaining


**@example**
```ruby
registry.register(attribute)
registry.register([attr1, attr2])
```