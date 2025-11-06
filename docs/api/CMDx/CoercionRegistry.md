# Class: CMDx::CoercionRegistry
**Inherits:** Object
    

Registry for managing type coercion handlers.

Provides a centralized way to register, deregister, and execute type coercions
for various data types including arrays, numbers, dates, and other primitives.


# Attributes
## registry[RW] [](#attribute-i-registry)
Returns the internal registry mapping coercion types to handler classes.

**@return** [Hash{Symbol => Class}] Hash of coercion type names to coercion classes


**@example**
```ruby
registry.registry # => { integer: Coercions::Integer, boolean: Coercions::Boolean }
```
# Instance Methods
## coerce(type, task, value, options{}) [](#method-i-coerce)
Coerce a value to the specified type using the registered handler.

**@param** [Symbol] the type to coerce to

**@param** [Object] the task context for the coercion

**@param** [Object] the value to coerce

**@param** [Hash] additional options for the coercion

**@raise** [TypeError] when the type is not registered

**@return** [Object] the coerced value


**@example**
```ruby
result = registry.coerce(:integer, task, "42")
result = registry.coerce(:boolean, task, "true", strict: true)
```## deregister(name) [](#method-i-deregister)
Remove a coercion handler for a type.

**@param** [Symbol, String] the type name to deregister

**@return** [CoercionRegistry] self for method chaining


**@example**
```ruby
registry.deregister(:custom_type)
registry.deregister("another_type")
```## dup() [](#method-i-dup)
Create a duplicate of this registry.

**@return** [CoercionRegistry] a new instance with duplicated registry hash


**@example**
```ruby
new_registry = registry.dup
```## initialize(registrynil) [](#method-i-initialize)
Initialize a new coercion registry.

**@param** [Hash<Symbol, Class>, nil] optional initial registry hash

**@return** [CoercionRegistry] a new instance of CoercionRegistry


**@example**
```ruby
registry = CoercionRegistry.new
registry = CoercionRegistry.new(custom: CustomCoercion)
```## register(name, coercion) [](#method-i-register)
Register a new coercion handler for a type.

**@param** [Symbol, String] the type name to register

**@param** [Class] the coercion class to handle this type

**@return** [CoercionRegistry] self for method chaining


**@example**
```ruby
registry.register(:custom_type, CustomCoercion)
registry.register("another_type", AnotherCoercion)
```