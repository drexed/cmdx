# Module: CMDx::Workflow::ClassMethods
    




# Instance Methods
## method_added(method_name) [](#method-i-method_added)
Prevents redefinition of the work method to maintain workflow integrity.

**@param** [Symbol] The name of the method being added

**@raise** [RuntimeError] If attempting to redefine the work method


**@example**
```ruby
class MyWorkflow
  include CMDx::Workflow
  # This would raise an error:
  # def work; end
end
```## pipeline() [](#method-i-pipeline)
Returns the collection of execution groups for this workflow.

**@return** [Array<ExecutionGroup>] Array of execution groups


**@example**
```ruby
class MyWorkflow
  include CMDx::Workflow
  task Task1
  task Task2
  puts pipeline.size # => 2
end
```## tasks(*tasks, **options) [](#method-i-tasks)
Adds multiple tasks to the workflow with optional configuration.

**@option** [] 

**@option** [] 

**@param** [Array<Class>] Array of task classes to add

**@param** [Hash] Configuration options for the task execution

**@raise** [TypeError] If any task is not a CMDx::Task subclass


**@example**
```ruby
class MyWorkflow
  include CMDx::Workflow
  tasks ValidateTask, ProcessTask, NotifyTask, breakpoints: [:failure, :halt]
end
```