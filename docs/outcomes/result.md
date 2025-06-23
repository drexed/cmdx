# Outcomes - Result

The result object is the comprehensive return value of task execution, providing
complete information about the execution outcome, state, timing, and any data
produced during the task lifecycle. Results serve as the primary interface for
inspecting task execution outcomes and chaining task operations.

## Core Result Attributes

Every result provides access to essential execution information:

```ruby
result = ProcessOrderTask.call(order_id: 123)

# Core objects
result.task     #=> <ProcessOrderTask instance>
result.context  #=> <CMDx::Context with all task data>
result.run      #=> <CMDx::Run execution tracking>
result.metadata #=> Hash with execution metadata

# Execution information
result.id       #=> "abc123..." (unique task execution ID)
result.state    #=> "complete" (execution state)
result.status   #=> "success" (execution outcome)
result.runtime  #=> 0.5 (execution time in seconds)
```

## State and Status Information

Results provide comprehensive methods for checking execution state and status:

```ruby
result = ProcessOrderTask.call

# State predicates (execution lifecycle)
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)
result.executed?    #=> true (execution finished)

# Status predicates (execution outcome)
result.success?     #=> true (successful execution)
result.skipped?     #=> false (not skipped)
result.failed?      #=> false (no failure)

# Outcome categorization
result.good?        #=> true (success or skipped)
result.bad?         #=> false (skipped or failed)
```

## Execution Outcome Analysis

Results provide additional methods for understanding execution outcomes:

```ruby
result = ComplexWorkflowTask.call

# Outcome determination
result.outcome      #=> "success" (combines state and status)

# For successful results
result.outcome == result.status    #=> true

# For failed/interrupted results
result.outcome == result.state     #=> may differ based on failure type
```

## Runtime and Performance

Results capture detailed timing information:

```ruby
result = ProcessOrderTask.call

# Execution timing
result.runtime      #=> 0.5 (total execution time in seconds)

# Runtime can also be used to measure blocks (internal use)
result.runtime do
  # Code execution is measured
  expensive_operation
end #=> returns execution time and stores it
```

## Failure Chain Analysis

For failed results, comprehensive failure analysis is available:

```ruby
result = ComplexWorkflowTask.call

if result.failed?
  # Find the original cause of failure
  original_failure = result.caused_failure
  if original_failure
    puts "Original failure: #{original_failure.task.class.name}"
    puts "Reason: #{original_failure.metadata[:reason]}"
  end

  # Find what threw the failure to this result
  throwing_task = result.threw_failure
  if throwing_task
    puts "Failure thrown by: #{throwing_task.task.class.name}"
  end

  # Failure classification
  result.caused_failure?  #=> true if this result was the original cause
  result.threw_failure?   #=> true if this result threw a failure
  result.thrown_failure?  #=> true if this result received a thrown failure
end
```

## Index and Position

Results track their position within execution runs:

```ruby
result = ProcessOrderTask.call

# Position in execution sequence
result.index        #=> 0 (first task in run)

# Access via run
result.run.results[result.index] == result #=> true
```

## Result Callbacks and Chaining

Results support fluent callback patterns for conditional logic:

```ruby
result = ProcessOrderTask.call

# State-based callbacks
result
  .on_complete { |r| logger.info "Task completed successfully" }
  .on_interrupted { |r| logger.warn "Task was interrupted" }
  .on_executed { |r| update_metrics(r.runtime) }

# Status-based callbacks
result
  .on_success { |r| send_confirmation_email(r.context) }
  .on_skipped { |r| logger.info "Skipped: #{r.metadata[:reason]}" }
  .on_failed { |r| handle_failure(r) }

# Outcome-based callbacks
result
  .on_good { |r| celebrate_success }
  .on_bad { |r| handle_problem }
```

### Callback Chaining Examples

```ruby
ProcessOrderTask
  .call(order_id: 123)
  .on_success { |result|
    NotificationService.call(result.context)
  }
  .on_failed { |result|
    ErrorReporter.notify(result.metadata)
  }
  .on_executed { |result|
    MetricsService.record_execution_time(result.runtime)
  }
```

## Serialization and Inspection

Results provide comprehensive serialization and inspection capabilities:

### Hash Serialization

```ruby
result = ProcessOrderTask.call

result.to_h
#=> {
#     class: "ProcessOrderTask",
#     type: "Task",
#     index: 0,
#     id: "abc123...",
#     run_id: "def456...",
#     tags: [],
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     metadata: {},
#     runtime: 0.5
#   }
```

### Human-Readable Inspection

```ruby
result = ProcessOrderTask.call

result.to_s
#=> "ProcessOrderTask: type=Task index=0 id=abc123... state=complete status=success outcome=success metadata={} runtime=0.5"
```

### Failure Chain Serialization

Failed results include failure chain information:

```ruby
failed_result = ComplexTask.call

failed_result.to_h
#=> {
#     # ... standard result data ...
#     caused_failure: {
#       class: "ValidationTask",
#       index: 1,
#       id: "xyz789...",
#       state: "interrupted",
#       status: "failed"
#     },
#     threw_failure: {
#       class: "ProcessingTask",
#       index: 2,
#       id: "uvw123...",
#       state: "interrupted",
#       status: "failed"
#     }
#   }
```

## Advanced Result Operations

### Result Propagation

Results can propagate failures to other results:

```ruby
class ProcessParentTask < CMDx::Task
  def call
    child_result = ChildTask.call(context)

    # Propagate child failure with additional context
    throw!(child_result, parent_context: "During parent execution") if child_result.failed?
  end
end
```

### Conditional Processing

```ruby
result = ProcessOrderTask.call

case result.status
when "success"
  complete_order_processing(result.context)
when "skipped"
  log_skip_reason(result.metadata[:reason])
when "failed"
  if result.metadata[:retryable]
    schedule_retry(result)
  else
    handle_permanent_failure(result)
  end
end
```

## Integration with Other Components

### With Context

```ruby
result = ProcessOrderTask.call(order_id: 123)

# Context is accessible through result
result.context.order_id     #=> 123
result.context.processed_at #=> (set during task execution)

# Context alias
result.ctx == result.context #=> true
```

### With Run

```ruby
result = ProcessOrderTask.call

# Run provides execution context
result.run.id               #=> "run-uuid"
result.run.results.size     #=> 1 (or more if subtasks executed)
result.run.state            #=> delegates to result.state
result.run.status           #=> delegates to result.status
```

### With Task

```ruby
result = ProcessOrderTask.call

# Task instance is accessible
result.task.class.name      #=> "ProcessOrderTask"
result.task.id              #=> "task-uuid"
result.task.context         #=> same as result.context
result.task.result          #=> same as result
```

## Best Practices

### Result Inspection

- **Use `result.good?` and `result.bad?`** for general outcome checking
- **Use specific status predicates** (`success?`, `failed?`, `skipped?`) for precise logic
- **Leverage callback methods** for clean conditional execution
- **Use `to_h` for serialization** and logging
- **Use `to_s` for human-readable** debugging output

### Error Handling

- **Check `result.failed?`** before accessing failure chain methods
- **Use `result.metadata`** to access structured error information
- **Leverage failure chain methods** for debugging complex workflows
- **Consider `outcome`** for unified state/status representation

### Performance Monitoring

- **Use `result.runtime`** for performance tracking
- **Monitor `result.index`** for execution order analysis
- **Combine with run-level metrics** for comprehensive monitoring

---

- **Prev:** [Interruptions - Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
- **Next:** [Outcomes - Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
