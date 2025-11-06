# Class: CMDx::ValidatorRegistry
**Inherits:** Object
  
**Extended by:** Forwardable
    

Registry for managing validation rules and their corresponding validator
classes. Provides methods to register, deregister, and execute validators
against task values.


# Attributes
## registry[RW] [](#attribute-i-registry)
Returns the internal registry mapping validator types to classes.

**@return** [Hash{Symbol => Class}] Hash of validator type names to validator classes


**@example**
```ruby
registry.registry # => { presence: Validators::Presence, format: Validators::Format }
```
# Instance Methods
## deregister(name) [](#method-i-deregister)
Remove a validator from the registry by name.

**@param** [String, Symbol] The name of the validator to remove

**@return** [ValidatorRegistry] Returns self for method chaining


**@example**
```ruby
registry.deregister(:format)
registry.deregister("presence")
```## dup() [](#method-i-dup)
Create a duplicate of the registry with copied internal state.

**@return** [ValidatorRegistry] A new validator registry with duplicated registry hash

## initialize(registrynil) [](#method-i-initialize)
Initialize a new validator registry with default validators.

**@param** [Hash, nil] Optional hash mapping validator names to validator classes

**@return** [ValidatorRegistry] A new validator registry instance

## register(name, validator) [](#method-i-register)
Register a new validator class with the given name.

**@param** [String, Symbol] The name to register the validator under

**@param** [Class] The validator class to register

**@return** [ValidatorRegistry] Returns self for method chaining


**@example**
```ruby
registry.register(:custom, CustomValidator)
registry.register("email", EmailValidator)
```## validate(type, task, value, options{}) [](#method-i-validate)
Validate a value using the specified validator type and options.

**@option** [] 

**@param** [Symbol] The type of validator to use

**@param** [Task] The task context for validation

**@param** [Object] The value to validate

**@param** [Hash, Object] Validation options or condition

**@raise** [TypeError] When the validator type is not registered


**@example**
```ruby
registry.validate(:presence, task, user.name, presence: true)
registry.validate(:length, task, password, { min: 8, allow_nil: false })
```