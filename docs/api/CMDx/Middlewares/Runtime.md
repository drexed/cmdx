# Module: CMDx::Middlewares::Runtime
  
**Extended by:** CMDx::Middlewares::Runtime
    

Middleware for measuring task execution runtime.

The Runtime middleware provides performance monitoring by measuring the
execution time of tasks using monotonic clock for accuracy. It stores runtime
measurements in task result metadata for analysis.


# Class Methods
## call(task , **options ) [](#method-c-call)
Middleware entry point that measures task execution runtime.

Evaluates the condition from options and measures execution time if enabled.
Uses monotonic clock for precise timing measurements and stores the result in
task metadata.
**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for runtime measurement

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Runtime.call(task, &block)
```
**@example**
```ruby
Runtime.call(task, if: :enable_profiling, &block)
```
**@example**
```ruby
Runtime.call(task, unless: :skip_profiling, &block)
```
# Instance Methods
## call(task, **options) [](#method-i-call)
Middleware entry point that measures task execution runtime.

Evaluates the condition from options and measures execution time if enabled.
Uses monotonic clock for precise timing measurements and stores the result in
task metadata.

**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for runtime measurement

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Runtime.call(task, &block)
```
**@example**
```ruby
Runtime.call(task, if: :enable_profiling, &block)
```
**@example**
```ruby
Runtime.call(task, unless: :skip_profiling, &block)
```