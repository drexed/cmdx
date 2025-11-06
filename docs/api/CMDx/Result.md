# Class: CMDx::Result
**Inherits:** Object
  
**Extended by:** Forwardable
    

Represents the execution result of a CMDx task, tracking state transitions,
status changes, and providing methods for handling different outcomes.

The Result class manages the lifecycle of task execution from initialization
through completion or interruption, offering a fluent interface for status
checking and conditional handling.


# Attributes
## cause[RW] [](#attribute-i-cause)
Returns the exception that caused the interruption.

**@return** [Exception, nil] The causing exception, or nil if not interrupted


**@example**
```ruby
result.cause # => #<StandardError: Connection timeout>
```## metadata[RW] [](#attribute-i-metadata)
Returns additional metadata about the result.

**@return** [Hash{Symbol => Object}] Metadata hash


**@example**
```ruby
result.metadata # => { duration: 1.5, retries: 2 }
```## reason[RW] [](#attribute-i-reason)
Returns the reason for interruption (skip or failure).

**@return** [String, nil] The reason message, or nil if not interrupted


**@example**
```ruby
result.reason # => "Validation failed"
```## state[RW] [](#attribute-i-state)
Returns the current execution state of the result.

**@return** [String] One of: "initialized", "executing", "complete", "interrupted"


**@example**
```ruby
result.state # => "complete"
```## status[RW] [](#attribute-i-status)
Returns the execution status of the result.

**@return** [String] One of: "success", "skipped", "failed"


**@example**
```ruby
result.status # => "success"
```## task[RW] [](#attribute-i-task)
Returns the task instance associated with this result.

**@return** [CMDx::Task] The task instance


**@example**
```ruby
result.task.id # => "users/create"
```
# Instance Methods
## bad?() [](#method-i-bad?)

**@return** [Boolean] Whether the task execution was unsuccessful (not success)


**@example**
```ruby
result.bad? # => true if !success?
```## caused_failure() [](#method-i-caused_failure)

**@return** [CMDx::Result, nil] The result that caused this failure, or nil


**@example**
```ruby
cause = result.caused_failure
puts "Caused by: #{cause.task.id}" if cause
```## caused_failure?() [](#method-i-caused_failure?)

**@return** [Boolean] Whether this result caused the failure


**@example**
```ruby
if result.caused_failure?
  puts "This task caused the failure"
end
```## complete!() [](#method-i-complete!)

**@raise** [RuntimeError] When attempting to transition from invalid state


**@example**
```ruby
result.complete! # Transitions from executing to complete
```## deconstruct() [](#method-i-deconstruct)

**@param** [Array] Array of keys to deconstruct

**@return** [Array] Array containing state, status, reason, cause, and metadata


**@example**
```ruby
state, status = result.deconstruct
puts "State: #{state}, Status: #{status}"
```## deconstruct_keys() [](#method-i-deconstruct_keys)

**@param** [Array] Array of keys to deconstruct

**@return** [Hash] Hash with key-value pairs for pattern matching


**@example**
```ruby
case result.deconstruct_keys
in {state: "complete", good: true}
  puts "Task completed successfully"
in {bad: true}
  puts "Task had issues"
end
```## executed!() [](#method-i-executed!)

**@return** [self] Returns self for method chaining


**@example**
```ruby
result.executed! # Transitions to complete or interrupted
```## executed?() [](#method-i-executed?)

**@return** [Boolean] Whether the task has been executed (complete or interrupted)


**@example**
```ruby
result.executed? # => true if complete? || interrupted?
```## executing!() [](#method-i-executing!)

**@raise** [RuntimeError] When attempting to transition from invalid state


**@example**
```ruby
result.executing! # Transitions from initialized to executing
```## fail!(reasonnil, halt:true, cause:nil, **metadata) [](#method-i-fail!)

**@param** [String, nil] Reason for task failure

**@param** [Boolean] Whether to halt execution after failure

**@param** [Exception, nil] Exception that caused the failure

**@param** [Hash] Additional metadata about the failure

**@raise** [RuntimeError] When attempting to fail from invalid status


**@example**
```ruby
result.fail!("Validation failed", cause: validation_error)
result.fail!("Network timeout", halt: false, timeout: 30)
```## good?() [](#method-i-good?)

**@return** [Boolean] Whether the task execution was successful (not failed)


**@example**
```ruby
result.good? # => true if !failed?
```## halt!() [](#method-i-halt!)

**@raise** [SkipFault] When task was skipped

**@raise** [FailFault] When task failed


**@example**
```ruby
result.halt! # Raises appropriate fault based on status
```## handle_bad() [](#method-i-handle_bad)

**@param** [Proc] Block to execute conditionally

**@raise** [ArgumentError] When no block is provided

**@return** [self] Returns self for method chaining

**@yield** [self] Executes the block if task execution was unsuccessful


**@example**
```ruby
result.handle_bad { |r| puts "Task had issues: #{r.reason}" }
```## handle_executed() [](#method-i-handle_executed)

**@param** [Proc] Block to execute conditionally

**@raise** [ArgumentError] When no block is provided

**@return** [self] Returns self for method chaining

**@yield** [self] Executes the block if task has been executed


**@example**
```ruby
result.handle_executed { |r| puts "Task finished: #{r.outcome}" }
```## handle_good() [](#method-i-handle_good)

**@param** [Proc] Block to execute conditionally

**@raise** [ArgumentError] When no block is provided

**@return** [self] Returns self for method chaining

**@yield** [self] Executes the block if task execution was successful


**@example**
```ruby
result.handle_good { |r| puts "Task completed successfully" }
```## index() [](#method-i-index)

**@return** [Integer] Index of this result in the chain


**@example**
```ruby
position = result.index
puts "Task #{position + 1} of #{chain.results.count}"
```## initialize(task) [](#method-i-initialize)

**@param** [CMDx::Task] The task instance this result represents

**@raise** [TypeError] When task is not a CMDx::Task instance

**@return** [CMDx::Result] A new result instance for the task


**@example**
```ruby
result = CMDx::Result.new(my_task)
result.state # => "initialized"
```## interrupt!() [](#method-i-interrupt!)

**@raise** [RuntimeError] When attempting to transition from invalid state


**@example**
```ruby
result.interrupt! # Transitions from executing to interrupted
```## outcome() [](#method-i-outcome)

**@return** [String] The outcome of the task execution


**@example**
```ruby
result.outcome # => "success" or "interrupted"
```## skip!(reasonnil, halt:true, cause:nil, **metadata) [](#method-i-skip!)

**@param** [String, nil] Reason for skipping the task

**@param** [Boolean] Whether to halt execution after skipping

**@param** [Exception, nil] Exception that caused the skip

**@param** [Hash] Additional metadata about the skip

**@raise** [RuntimeError] When attempting to skip from invalid status


**@example**
```ruby
result.skip!("Dependencies not met", cause: dependency_error)
result.skip!("Already processed", halt: false)
```## threw_failure() [](#method-i-threw_failure)

**@return** [CMDx::Result, nil] The result that threw this failure, or nil


**@example**
```ruby
thrown = result.threw_failure
puts "Thrown by: #{thrown.task.id}" if thrown
```## threw_failure?() [](#method-i-threw_failure?)

**@return** [Boolean] Whether this result threw the failure


**@example**
```ruby
if result.threw_failure?
  puts "This task threw the failure"
end
```## throw!(result, halt:true, cause:nil, **metadata) [](#method-i-throw!)

**@param** [CMDx::Result] Result to throw from current result

**@param** [Boolean] Whether to halt execution after throwing

**@param** [Exception, nil] Exception that caused the throw

**@param** [Hash] Additional metadata to merge

**@raise** [TypeError] When result is not a CMDx::Result instance


**@example**
```ruby
other_result = OtherTask.execute
result.throw!(other_result, cause: upstream_error)
```## thrown_failure?() [](#method-i-thrown_failure?)

**@return** [Boolean] Whether this result is a thrown failure


**@example**
```ruby
if result.thrown_failure?
  puts "This failure was thrown from another task"
end
```## to_h() [](#method-i-to_h)

**@return** [Hash] Hash representation of the result


**@example**
```ruby
result.to_h
# => {state: "complete", status: "success", outcome: "success", metadata: {}}
```## to_s() [](#method-i-to_s)

**@return** [String] String representation of the result


**@example**
```ruby
result.to_s # => "task_id=my_task state=complete status=success"
```