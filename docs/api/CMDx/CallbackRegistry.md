# Class: CMDx::CallbackRegistry
**Inherits:** Object
    

Registry for managing callbacks that can be executed at various points during
task execution.

Callbacks are organized by type and can be registered with optional conditions
and options. Each callback type represents a specific execution phase or
outcome.


# Attributes
## registry[RW] [](#attribute-i-registry)
Returns the internal registry of callbacks organized by type.

**@return** [Hash{Symbol => Set<Array>}] Hash mapping callback types to their registered callables


**@example**
```ruby
registry.registry # => { before_execution: #<Set: [[[:validate], {}]]> }
```
# Instance Methods
## deregister(type, *callables, **options, &block) [](#method-i-deregister)
Removes one or more callables for a specific callback type

**@param** [Symbol] The callback type from TYPES

**@param** [Array<#call>] Callable objects to remove

**@param** [Hash] Options that were used during registration

**@param** [Proc] Optional block to remove

**@return** [CallbackRegistry] self for method chaining


**@example**
```ruby
registry.deregister(:before_execution, :validate_inputs)
```## dup() [](#method-i-dup)
Creates a deep copy of the registry with duplicated callable sets

**@return** [CallbackRegistry] A new instance with duplicated registry contents

## initialize(registry{}) [](#method-i-initialize)

**@param** [Hash] Initial registry hash, defaults to empty

**@return** [CallbackRegistry] a new instance of CallbackRegistry

## invoke(type, task) [](#method-i-invoke)
Invokes all registered callbacks for a given type

**@param** [Symbol] The callback type to invoke

**@param** [Task] The task instance to pass to callbacks

**@raise** [TypeError] When type is not a valid callback type


**@example**
```ruby
registry.invoke(:before_execution, task)
```## register(type, *callables, **options, &block) [](#method-i-register)
Registers one or more callables for a specific callback type

**@option** [] 

**@option** [] 

**@param** [Symbol] The callback type from TYPES

**@param** [Array<#call>] Callable objects to register

**@param** [Hash] Options to pass to the callback

**@param** [Proc] Optional block to register as a callable

**@raise** [ArgumentError] When type is not a valid callback type

**@return** [CallbackRegistry] self for method chaining


**@example**
```ruby
registry.register(:before_execution, :validate_inputs)
```
**@example**
```ruby
registry.register(:on_success, if: { status: :completed }) do |task|
  task.log("Success callback executed")
end
```