# Outcomes - Result

The result object is the comprehensive return value of task execution, providing
complete information about the execution outcome, state, timing, and any data
produced during the task lifecycle. Results serve as the primary interface for
inspecting task execution outcomes and chaining task operations.

## Table of Contents

- [Core Result Attributes](#core-result-attributes)
- [State and Status Information](#state-and-status-information)
- [Execution Outcome Analysis](#execution-outcome-analysis)
- [Runtime and Performance](#runtime-and-performance)
- [Failure Chain Analysis](#failure-chain-analysis)
- [Index and Position](#index-and-position)
- [Result Callbacks and Chaining](#result-callbacks-and-chaining)
- [Pattern Matching](#pattern-matching)
- [Serialization and Inspection](#serialization-and-inspection)
- [Advanced Result Operations](#advanced-result-operations)
- [Integration with Other Components](#integration-with-other-components)

## Core Result Attributes

Every result provides access to essential execution information:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)

# Core objects
result.task     #=> <ProcessUserOrderTask instance>
result.context  #=> <CMDx::Context with all task data>
result.run      #=> <CMDx::Run execution tracking>
result.metadata #=> Hash with execution metadata

# Execution information
result.id       #=> "abc123..." (unique task execution ID)
result.state    #=> "complete" (execution state)
result.status   #=> "success" (execution outcome)
result.runtime  #=> 0.5 (execution time in seconds)
```

> [!NOTE]
> Result objects are immutable after task execution completes. All result data reflects the final state of the task execution and cannot be modified.

## State and Status Information

Results provide comprehensive methods for checking execution state and status:

```ruby
result = ProcessUserOrderTask.call

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
result = ProcessOrderWorkflowTask.call

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
result = ProcessUserOrderTask.call

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
result = ProcessOrderWorkflowTask.call

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

> [!IMPORTANT]
> Failure chain analysis is only available for failed results. Use these methods to trace the root cause of failures in complex task workflows.

## Index and Position

Results track their position within execution runs:

```ruby
result = ProcessUserOrderTask.call

# Position in execution sequence
result.index        #=> 0 (first task in run)

# Access via run
result.run.results[result.index] == result #=> true
```

## Result Callbacks and Chaining

Results support fluent callback patterns for conditional logic:

```ruby
result = ProcessUserOrderTask.call

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
ProcessUserOrderTask
  .call(order_id: 123)
  .on_success { |result|
    SendOrderNotificationTask.call(result.context)
  }
  .on_failed { |result|
    ErrorReporter.notify(result.metadata)
  }
  .on_executed { |result|
    MetricsService.record_execution_time(result.runtime)
  }
```

> [!TIP]
> Use result callbacks for clean, functional-style conditional logic. Callbacks return the result object, enabling method chaining and fluent interfaces.

## Pattern Matching

Results support Ruby's pattern matching (Ruby 3.0+) through array and hash deconstruction:

### Array Pattern Matching

Match against state and status in order:

```ruby
result = ProcessUserOrderTask.call

case result
in ["complete", "success"]
  puts "Task completed successfully"
in ["interrupted", "failed"]
  puts "Task failed during execution"
in ["complete", "skipped"]
  puts "Task was skipped but completed"
end
```

### Hash Pattern Matching

Match against specific result attributes:

```ruby
result = ProcessUserOrderTask.call

case result
in { state: "complete", status: "success" }
  puts "Perfect execution!"
in { state: "interrupted", status: "failed", metadata: { retryable: true } }
  puts "Failed but can retry"
in { good: true }
  puts "Execution went well overall"
in { bad: true, metadata: { reason: String => reason } }
  puts "Something went wrong: #{reason}"
end
```

### Advanced Pattern Matching

Combine patterns for complex matching logic:

```ruby
results = BatchProcessTask.call.run.results

results.each do |result|
  case result
  in { state: "complete", status: "success", metadata: { processed_count: n } } if n > 100
    puts "High-volume processing completed: #{n} items"
  in { executed: true, runtime: time } if time > 5.0
    puts "Long-running task completed in #{time}s"
  in { bad: true, metadata: { error_code: code } }
    handle_error_by_code(code)
  else
    puts "Standard result: #{result}"
  end
end
```

### Pattern Matching with Guards

Use guard clauses for conditional matching:

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_task(result)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  give_up_task(result)
in { runtime: time } if time > threshold
  log_performance_issue(result)
end
```

> [!NOTE]
> Pattern matching requires Ruby 3.0+. The `deconstruct` method returns `[state, status]` for array patterns, while `deconstruct_keys` provides hash access to `state`, `status`, `metadata`, `executed`, `good`, and `bad` attributes.

## Serialization and Inspection

Results provide comprehensive serialization and inspection capabilities:

### Hash Serialization

```ruby
result = ProcessUserOrderTask.call

result.to_h
#=> {
#     class: "ProcessUserOrderTask",
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
result = ProcessUserOrderTask.call

result.to_s
#=> "ProcessUserOrderTask: type=Task index=0 id=abc123... state=complete status=success outcome=success metadata={} runtime=0.5"
```

### Failure Chain Serialization

Failed results include failure chain information:

```ruby
failed_result = ProcessOrderWorkflowTask.call

failed_result.to_h
#=> {
#     # ... standard result data ...
#     caused_failure: {
#       class: "ValidateUserOrderTask",
#       index: 1,
#       id: "xyz789...",
#       state: "interrupted",
#       status: "failed"
#     },
#     threw_failure: {
#       class: "ProcessOrderPaymentTask",
#       index: 2,
#       id: "uvw123...",
#       state: "interrupted",
#       status: "failed"
#     }
#   }
```

> [!NOTE]
> Serialized results include complete failure chain information for debugging and audit trails. Use `to_h` for structured data and `to_s` for human-readable output.

## Advanced Result Operations

### Result Propagation

Results can propagate failures to other results:

```ruby
class ProcessOrderBatchTask < CMDx::Task
  def call
    child_result = ValidateOrderDataTask.call(context)

    # Propagate child failure with additional context
    throw!(child_result, parent_context: "During batch processing") if child_result.failed?
  end
end
```

### Conditional Processing

```ruby
result = ProcessUserOrderTask.call

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
result = ProcessUserOrderTask.call(order_id: 123)

# Context is accessible through result
result.context.order_id     #=> 123
result.context.processed_at #=> (set during task execution)

# Context alias
result.ctx == result.context #=> true
```

### With Run

```ruby
result = ProcessUserOrderTask.call

# Run provides execution context
result.run.id               #=> "run-uuid"
result.run.results.size     #=> 1 (or more if subtasks executed)
result.run.state            #=> delegates to result.state
result.run.status           #=> delegates to result.status
```

### With Task

```ruby
result = ProcessUserOrderTask.call

# Task instance is accessible
result.task.class.name      #=> "ProcessUserOrderTask"
result.task.id              #=> "task-uuid"
result.task.context         #=> same as result.context
result.task.result          #=> same as result
```

---

- **Prev:** [Interruptions - Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
- **Next:** [Outcomes - Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
