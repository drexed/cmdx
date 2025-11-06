# Class: CMDx::Task
**Inherits:** Object
  
**Extended by:** Forwardable
    

Represents a task that can be executed within the CMDx framework. Tasks define
attributes, callbacks, and execution logic that can be chained together to
form workflows.


# Class Methods
## attributes() [](#method-c-attributes)
**@param** [Array] Arguments to build the attribute with


**@example**
```ruby
attributes :name, :email
attributes :age, type: Integer, default: 18
```## deregister(type , object ) [](#method-c-deregister)
**@param** [Symbol] The type of registry to deregister from

**@param** [Object] The object to deregister

**@param** [Array] Additional arguments for deregistration

**@raise** [RuntimeError] If the registry type is unknown


**@example**
```ruby
deregister(:attribute, :name)
deregister(:callback, :before, MyCallback)
```## execute(*args , **kwargs ) [](#method-c-execute)
**@param** [Array] Arguments to pass to the task constructor

**@return** [Result] The execution result


**@example**
```ruby
result = MyTask.execute(name: "example")
if result.success?
  puts "Task completed successfully"
end
```## execute!(*args , **kwargs ) [](#method-c-execute!)
**@param** [Array] Arguments to pass to the task constructor

**@raise** [ExecutionError] If the task execution fails

**@return** [Result] The execution result


**@example**
```ruby
result = MyTask.execute!(name: "example")
# Will raise an exception if execution fails
```## optional() [](#method-c-optional)
**@param** [Array] Arguments to build the optional attribute with


**@example**
```ruby
optional :description, :notes
optional :priority, type: Symbol, default: :normal
```## register(type , object ) [](#method-c-register)
**@param** [Symbol] The type of registry to register with

**@param** [Object] The object to register

**@param** [Array] Additional arguments for registration

**@raise** [RuntimeError] If the registry type is unknown


**@example**
```ruby
register(:attribute, MyAttribute.new)
register(:callback, :before, -> { puts "before" })
```## remove_attributes(*names ) [](#method-c-remove_attributes)
**@param** [Array<Symbol>] Names of attributes to remove


**@example**
```ruby
remove_attributes :old_field, :deprecated_field
```## required() [](#method-c-required)
**@param** [Array] Arguments to build the required attribute with


**@example**
```ruby
required :name, :email
required :age, type: Integer, min: 0
```## settings(**options ) [](#method-c-settings)
**@param** [Hash] Configuration options to merge with existing settings

**@return** [Hash] The merged settings hash


**@example**
```ruby
class MyTask < Task
  settings deprecate: true, tags: [:experimental]
end
```# Attributes
## attributes[RW] [](#attribute-i-attributes)
Returns the hash of processed attribute values for this task.

**@return** [Hash{Symbol => Object}] Hash of attribute names to their values


**@example**
```ruby
task.attributes # => { user_id: 42, user_name: "John" }
```## chain[RW] [](#attribute-i-chain)
Returns the execution chain containing all task results.

**@return** [Chain] The chain instance


**@example**
```ruby
task.chain.results.size # => 3
```## context[RW] [](#attribute-i-context)
Returns the execution context for this task.

**@return** [Context] The context instance


**@example**
```ruby
task.context[:user_id] # => 42
```## errors[RW] [](#attribute-i-errors)
Returns the collection of validation and execution errors.

**@return** [Errors] The errors collection


**@example**
```ruby
task.errors.to_h # => { email: ["must be valid"] }
```## id[RW] [](#attribute-i-id)
Returns the unique identifier for this task instance.

**@return** [String] The task identifier


**@example**
```ruby
task.id # => "abc123xyz"
```## result[RW] [](#attribute-i-result)
Returns the execution result for this task.

**@return** [Result] The result instance


**@example**
```ruby
task.result.status # => "success"
```
# Instance Methods
## execute(raise:false) [](#method-i-execute)

**@param** [Boolean] Whether to raise exceptions on failure

**@return** [Result] The execution result


**@example**
```ruby
result = task.execute
result = task.execute(raise: true)
```## initialize(context{}) [](#method-i-initialize)

**@option** [] 

**@param** [Hash, Context] The initial context for the task

**@raise** [DeprecationError] If the task class is deprecated

**@return** [Task] A new task instance


**@example**
```ruby
task = MyTask.new(name: "example", priority: :high)
task = MyTask.new(Context.build(name: "example"))
```## logger() [](#method-i-logger)

**@return** [Logger] The logger instance for this task


**@example**
```ruby
logger.info "Starting task execution"
logger.error "Task failed", error: exception
```## to_h() [](#method-i-to_h)

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Hash] a customizable set of options

**@return** [Hash] A hash representation of the task


**@example**
```ruby
task_hash = task.to_h
puts "Task type: #{task_hash[:type]}"
puts "Task tags: #{task_hash[:tags].join(', ')}"
```## to_s() [](#method-i-to_s)

**@return** [String] A string representation of the task


**@example**
```ruby
puts task.to_s
# Output: "Task[MyTask] tags: [:important] id: abc123"
```## work() [](#method-i-work)

**@raise** [UndefinedMethodError] Always raised as this method must be overridden


**@example**
```ruby
class MyTask < Task
  def work
    # Custom work logic here
    puts "Performing work..."
  end
end
```