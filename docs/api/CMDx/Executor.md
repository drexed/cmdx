# Class: CMDx::Executor
**Inherits:** Object
    

Executes CMDx tasks with middleware support, error handling, and lifecycle
management.

The Executor class is responsible for orchestrating task execution, including
pre-execution validation, execution with middleware, post-execution callbacks,
and proper error handling for different types of failures.


# Class Methods
## execute(task , raise: false) [](#method-c-execute)
Executes a task with optional exception raising.
**@param** [CMDx::Task] The task to execute

**@param** [Boolean] Whether to raise exceptions (default: false)

**@raise** [StandardError] When raise is true and execution fails

**@return** [CMDx::Result] The execution result


**@example**
```ruby
CMDx::Executor.execute(my_task)
CMDx::Executor.execute(my_task, raise: true)
```# Attributes
## task[RW] [](#attribute-i-task)
Returns the task being executed.

**@return** [Task] The task instance


**@example**
```ruby
executor.task.id # => "abc123"
```
# Instance Methods
## execute() [](#method-i-execute)
Executes the task with graceful error handling.

**@return** [CMDx::Result] The execution result


**@example**
```ruby
executor = CMDx::Executor.new(my_task)
result = executor.execute
```## execute!() [](#method-i-execute!)
Executes the task with exception raising on failure.

**@raise** [StandardError] When execution fails

**@return** [CMDx::Result] The execution result


**@example**
```ruby
executor = CMDx::Executor.new(my_task)
result = executor.execute!
```## initialize(task) [](#method-i-initialize)

**@param** [CMDx::Task] The task to execute

**@return** [CMDx::Executor] A new executor instance


**@example**
```ruby
executor = CMDx::Executor.new(my_task)
```