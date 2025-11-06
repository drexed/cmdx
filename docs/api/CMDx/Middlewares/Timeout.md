# Module: CMDx::Middlewares::Timeout
  
**Extended by:** CMDx::Middlewares::Timeout
    

Middleware for enforcing execution time limits on tasks.

The Timeout middleware provides execution time control by wrapping task
execution with Ruby's Timeout module. It automatically fails tasks that exceed
the configured time limit and provides detailed error information including
the exceeded limit.


# Class Methods
## call(task , **options ) [](#method-c-call)
Middleware entry point that enforces execution time limits.

Evaluates the condition from options and applies timeout control if enabled.
Supports various timeout limit configurations including numeric values, task
method calls, and dynamic proc evaluation.
**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for timeout control

**@raise** [TimeoutError] When execution exceeds the configured limit

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Timeout.call(task, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: 10, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: :timeout_limit, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: -> { calculate_timeout }, &block)
```
**@example**
```ruby
Timeout.call(task, if: :enable_timeout, &block)
```
# Instance Methods
## call(task, **options) [](#method-i-call)
Middleware entry point that enforces execution time limits.

Evaluates the condition from options and applies timeout control if enabled.
Supports various timeout limit configurations including numeric values, task
method calls, and dynamic proc evaluation.

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for timeout control

**@raise** [TimeoutError] When execution exceeds the configured limit

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Timeout.call(task, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: 10, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: :timeout_limit, &block)
```
**@example**
```ruby
Timeout.call(task, seconds: -> { calculate_timeout }, &block)
```
**@example**
```ruby
Timeout.call(task, if: :enable_timeout, &block)
```