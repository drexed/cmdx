# Class: CMDx::Pipeline
**Inherits:** Object
    

Executes workflows by processing task groups with conditional logic and
breakpoint handling. The Pipeline class manages the execution flow of workflow
tasks, evaluating conditions and handling breakpoints that can interrupt
execution at specific task statuses.


# Class Methods
## execute(workflow ) [](#method-c-execute)
Executes a workflow using a new pipeline instance.
**@param** [Workflow] The workflow to execute

**@return** [void] 


**@example**
```ruby
Pipeline.execute(my_workflow)
```# Attributes
## workflow[RW] [](#attribute-i-workflow)
Returns the workflow being executed by this pipeline.

**@return** [Workflow] The workflow instance


**@example**
```ruby
pipeline.workflow.context[:status] # => "processing"
```
# Instance Methods
## execute() [](#method-i-execute)
Executes the workflow by processing all task groups in sequence. Each group is
evaluated against its conditions, and breakpoints are checked after each task
execution to determine if workflow should continue or halt.

**@return** [void] 


**@example**
```ruby
pipeline = Pipeline.new(my_workflow)
pipeline.execute
```## initialize(workflow) [](#method-i-initialize)

**@param** [Workflow] The workflow to execute

**@return** [Pipeline] A new pipeline instance


**@example**
```ruby
pipeline = Pipeline.new(my_workflow)
```