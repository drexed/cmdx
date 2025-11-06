# Class: CMDx::MiddlewareRegistry
**Inherits:** Object
    

Registry for managing middleware components in a task execution chain.

The MiddlewareRegistry maintains an ordered list of middleware components that
can be inserted, removed, and executed in sequence. Each middleware can be
configured with specific options and is executed in the order they were
registered.


# Attributes
## registry[RW] [](#attribute-i-registry)
Returns the ordered collection of middleware entries.

**@return** [Array<Array>] Array of middleware-options pairs


**@example**
```ruby
registry.registry # => [[LoggingMiddleware, {level: :debug}], [AuthMiddleware, {}]]
```
# Instance Methods
## call!(task) [](#method-i-call!)
Execute the middleware chain for a given task.

**@param** [Object] The task object to process through middleware

**@raise** [ArgumentError] When no block is provided

**@return** [Object] Result of the block execution

**@yield** [task] Block to execute after all middleware processing

**@yieldparam** [Object] The processed task object


**@example**
```ruby
result = registry.call!(my_task) do |processed_task|
  processed_task.execute
end
```## deregister(middleware) [](#method-i-deregister)
Remove a middleware component from the registry.

**@param** [Object] The middleware object to remove

**@return** [MiddlewareRegistry] Returns self for method chaining


**@example**
```ruby
registry.deregister(LoggingMiddleware)
```## dup() [](#method-i-dup)
Create a duplicate of the registry with duplicated middleware entries.

**@return** [MiddlewareRegistry] A new registry instance with duplicated entries


**@example**
```ruby
new_registry = registry.dup
```## initialize(registry[]) [](#method-i-initialize)
Initialize a new middleware registry.

**@param** [Array] Initial array of middleware entries

**@return** [MiddlewareRegistry] a new instance of MiddlewareRegistry


**@example**
```ruby
registry = MiddlewareRegistry.new
registry = MiddlewareRegistry.new([[MyMiddleware, {option: 'value'}]])
```## register(middleware, at:-1,, **options) [](#method-i-register)
Register a middleware component in the registry.

**@option** [] 

**@option** [] 

**@param** [Object] The middleware object to register

**@param** [Integer] Position to insert the middleware (default: -1, end of list)

**@param** [Hash] Configuration options for the middleware

**@return** [MiddlewareRegistry] Returns self for method chaining


**@example**
```ruby
registry.register(LoggingMiddleware, at: 0, log_level: :debug)
registry.register(AuthMiddleware, at: -1, timeout: 30)
```