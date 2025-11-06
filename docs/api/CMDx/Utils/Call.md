# Module: CMDx::Utils::Call
  
**Extended by:** CMDx::Utils::Call
    

Utility module for invoking callable objects with different invocation
strategies.

This module provides a unified interface for calling methods, procs, and other
callable objects on target objects, handling the appropriate invocation method
based on the callable type.


# Class Methods
## invoke(target , callable , *args , **kwargs ) [](#method-c-invoke)
Invokes a callable object on the target with the given arguments.
**@param** [Object] The target object to invoke the callable on

**@param** [Symbol, Proc, #call] The callable to invoke

**@param** [Array] Positional arguments to pass to the callable

**@param** [Hash] Keyword arguments to pass to the callable

**@param** [Proc, nil] Block to pass to the callable

**@raise** [RuntimeError] When the callable cannot be invoked

**@return** [Object] The result of invoking the callable


**@example**
```ruby
Call.invoke(user, :name)
Call.invoke(user, :update, { name: 'John' })
```
**@example**
```ruby
proc = ->(name) { "Hello #{name}" }
Call.invoke(user, proc, 'John')
```
**@example**
```ruby
callable = MyCallable.new
Call.invoke(user, callable, 'data')
```
# Instance Methods
## invoke(target, callable, *args, **kwargs) [](#method-i-invoke)
Invokes a callable object on the target with the given arguments.

**@param** [Object] The target object to invoke the callable on

**@param** [Symbol, Proc, #call] The callable to invoke

**@param** [Array] Positional arguments to pass to the callable

**@param** [Hash] Keyword arguments to pass to the callable

**@param** [Proc, nil] Block to pass to the callable

**@raise** [RuntimeError] When the callable cannot be invoked

**@return** [Object] The result of invoking the callable


**@example**
```ruby
Call.invoke(user, :name)
Call.invoke(user, :update, { name: 'John' })
```
**@example**
```ruby
proc = ->(name) { "Hello #{name}" }
Call.invoke(user, proc, 'John')
```
**@example**
```ruby
callable = MyCallable.new
Call.invoke(user, callable, 'data')
```