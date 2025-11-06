# Module: CMDx::Workflow
    

Provides workflow execution capabilities by organizing tasks into execution
groups. Workflows allow you to define sequences of tasks that can be executed
conditionally with breakpoint handling and context management.


# Class Methods
## included(base ) [](#method-c-included)
Extends the including class with workflow capabilities.
**@param** [Class] The class including this module


**@example**
```ruby
class MyWorkflow
  include CMDx::Workflow
  # Now has access to task, tasks, and work methods
end
```
# Instance Methods
## work() [](#method-i-work)
Executes the workflow by processing all tasks in the pipeline. This method
delegates execution to the Pipeline class which handles the processing of
tasks with proper error handling and context management.


**@example**
```ruby
class MyWorkflow
  include CMDx::Workflow
  task ValidateTask
  task ProcessTask
end

workflow = MyWorkflow.new
result = workflow.work
```