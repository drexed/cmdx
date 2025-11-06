# Module: CMDx::Utils::Condition
  
**Extended by:** CMDx::Utils::Condition
    

Provides conditional evaluation utilities for CMDx tasks and workflows.

This module handles conditional logic evaluation with support for `if` and
`unless` conditions using various callable types including symbols, procs, and
objects responding to `call`.


# Class Methods
## evaluate(target , options ) [](#method-c-evaluate)
Evaluates conditional logic based on provided options.

Supports both `if` and `unless` conditions, with `unless` taking precedence
when both are specified. Returns true if no conditions are provided.
**@option** [] 

**@option** [] 

**@param** [Object] The target object to evaluate conditions against

**@param** [Hash] Conditional options hash

**@param** [Array] Additional arguments passed to condition evaluation

**@param** [Hash] Additional keyword arguments passed to condition evaluation

**@param** [Proc, nil] Optional block passed to condition evaluation

**@raise** [RuntimeError] When a callable cannot be evaluated

**@return** [Boolean] true if conditions are met, false otherwise


**@example**
```ruby
Condition.evaluate(user, if: :active?)
# => true if user.active? returns true
```
**@example**
```ruby
Condition.evaluate(user, unless: :blocked?)
# => true if user.blocked? returns false
```
**@example**
```ruby
Condition.evaluate(user, if: :verified?, unless: :suspended?)
# => true if user.verified? is true AND user.suspended? is false
```
**@example**
```ruby
Condition.evaluate(user, if: ->(u) { u.has_permission?(:admin) }, :admin)
# => true if the proc returns true when called with user and :admin
```
# Instance Methods
## evaluate(target, options) [](#method-i-evaluate)
Evaluates conditional logic based on provided options.

Supports both `if` and `unless` conditions, with `unless` taking precedence
when both are specified. Returns true if no conditions are provided.

**@option** [] 

**@option** [] 

**@param** [Object] The target object to evaluate conditions against

**@param** [Hash] Conditional options hash

**@param** [Array] Additional arguments passed to condition evaluation

**@param** [Hash] Additional keyword arguments passed to condition evaluation

**@param** [Proc, nil] Optional block passed to condition evaluation

**@raise** [RuntimeError] When a callable cannot be evaluated

**@return** [Boolean] true if conditions are met, false otherwise


**@example**
```ruby
Condition.evaluate(user, if: :active?)
# => true if user.active? returns true
```
**@example**
```ruby
Condition.evaluate(user, unless: :blocked?)
# => true if user.blocked? returns false
```
**@example**
```ruby
Condition.evaluate(user, if: :verified?, unless: :suspended?)
# => true if user.verified? is true AND user.suspended? is false
```
**@example**
```ruby
Condition.evaluate(user, if: ->(u) { u.has_permission?(:admin) }, :admin)
# => true if the proc returns true when called with user and :admin
```