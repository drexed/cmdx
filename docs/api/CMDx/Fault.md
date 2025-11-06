# Class: CMDx::Fault
**Inherits:** Error
  
**Extended by:** Forwardable
    

Base fault class for handling task execution failures and interruptions.

Faults represent error conditions that occur during task execution, providing
a structured way to handle and categorize different types of failures. Each
fault contains a reference to the result object that caused the fault.


# Class Methods
## for?(*tasks ) [](#method-c-for?)
Create a fault class that matches specific task types.
**@param** [Array<Class>] array of task classes to match against

**@return** [Class] a new fault class that matches the specified tasks


**@example**
```ruby
Fault.for?(UserTask, AdminUserTask)
# => true if fault.task is a UserTask or AdminUserTask
```## matches?(&block ) [](#method-c-matches?)
Create a fault class that matches based on a custom block.
**@param** [Proc] block that determines if a fault matches

**@raise** [ArgumentError] if no block is provided

**@return** [Class] a new fault class that matches based on the block


**@example**
```ruby
Fault.matches? { |fault| fault.result.metadata[:critical] }
# => true if fault has critical metadata
```# Attributes
## result[RW] [](#attribute-i-result)
Returns the result that caused this fault.

**@return** [Result] The result instance


**@example**
```ruby
fault.result.reason # => "Validation failed"
```
# Instance Methods
## initialize(result) [](#method-i-initialize)
Initialize a new fault with the given result.

**@param** [Result] the result object that caused this fault

**@raise** [ArgumentError] if result is nil or invalid

**@return** [Fault] a new instance of Fault


**@example**
```ruby
fault = Fault.new(task_result)
fault.result.reason # => "Task validation failed"
```