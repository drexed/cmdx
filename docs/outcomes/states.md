# Outcomes - States

States represent the execution lifecycle condition of task execution, tracking
the progress of tasks through their complete execution journey. States provide
insight into where a task is in its lifecycle and enable lifecycle-based
decision making and monitoring.

## State Definitions

| State         | Description |
| ------------- | ----------- |
| `initialized` | Task created but execution not yet started. Default state for new tasks. |
| `executing`   | Task is actively running its business logic. Transient state during execution. |
| `complete`    | Task finished execution successfully without any interruption or halt. |
| `interrupted` | Task execution was stopped due to a fault, exception, or explicit halt. |

## State Transitions

States follow a strict lifecycle with controlled transitions:

```ruby
# Valid state transition flow
initialized -> executing -> complete    (successful execution)
initialized -> executing -> interrupted (failed/halted execution)
```

### Automatic State Management

States are automatically managed during task execution and should **never** be modified manually:

```ruby
task = ProcessOrderTask.new
task.result.state #=> "initialized"

# During task execution, states transition automatically:
# 1. initialized -> executing (when call begins)
# 2. executing -> complete (successful completion)
# 3. executing -> interrupted (on failure/halt)

result = ProcessOrderTask.call
result.state #=> "complete" (if successful)
```

### State Transition Methods (Internal Use)

These methods handle state transitions internally and are not intended for direct use:

```ruby
result = ProcessOrderTask.new.result

# Internal state transition methods
result.executing!   # initialized -> executing
result.complete!    # executing -> complete
result.interrupt!   # executing -> interrupted
result.executed!    # executing -> complete OR interrupted (based on status)
```

## State Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = ProcessOrderTask.call

# Check current state
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# Combined state checking
result.executed?    #=> true (complete OR interrupted)
```

### State Predicate Usage Examples

```ruby
# Check if task is still running
if result.executing?
  puts "Task is still processing..."
end

# Check if execution finished
if result.executed?
  puts "Task execution completed"

  if result.complete?
    handle_successful_completion(result)
  elsif result.interrupted?
    handle_interruption(result)
  end
end

# Initial state checking
unless result.executed?
  puts "Task hasn't finished executing yet"
end
```

## State-Based Callbacks

Results provide callback methods for state-based conditional execution:

```ruby
result = ProcessOrderTask.call

# Individual state callbacks
result
  .on_initialized { |r| log_task_created(r) }
  .on_executing { |r| show_progress_indicator(r) }
  .on_complete { |r| celebrate_success(r) }
  .on_interrupted { |r| handle_interruption(r) }

# Execution completion callback (complete OR interrupted)
result
  .on_executed { |r| cleanup_resources(r) }
```

### Callback Chaining and Combinations

```ruby
ProcessOrderTask
  .call(order_id: 123)
  .on_complete { |result|
    # Only runs if task completed successfully
    send_confirmation_email(result.context)
    update_order_status(result.context.order)
  }
  .on_interrupted { |result|
    # Only runs if task was interrupted
    log_interruption(result.metadata)
    schedule_retry(result) if result.metadata[:retryable]
  }
  .on_executed { |result|
    # Always runs after execution (complete OR interrupted)
    update_metrics(result.runtime)
    cleanup_temporary_files(result.context)
  }
```

## State vs Status Distinction

Understanding the difference between states and statuses is crucial:

- **State**: Execution lifecycle position (`initialized` → `executing` → `complete`/`interrupted`)
- **Status**: Execution outcome (`success`, `skipped`, `failed`)

```ruby
result = ProcessOrderTask.call

# State indicates WHERE in the lifecycle
result.state    #=> "complete" (finished executing)

# Status indicates HOW the execution ended
result.status   #=> "success" (executed successfully)

# Both can be different for interrupted tasks
failed_result = FailingTask.call rescue nil
failed_result.state   #=> "interrupted" (execution stopped)
failed_result.status  #=> "failed" (outcome was failure)
```

### State-Status Combinations

| State         | Status    | Meaning |
| ------------- | --------- | ------- |
| `initialized` | `success` | Task created, not yet executed |
| `executing`   | `success` | Task currently running |
| `complete`    | `success` | Task finished successfully |
| `complete`    | `skipped` | Task finished by skipping execution |
| `interrupted` | `failed`  | Task stopped due to failure |
| `interrupted` | `skipped` | Task stopped by skip condition |

## State Inspection and Monitoring

States provide valuable information for monitoring and debugging:

```ruby
result = ProcessOrderTask.call

# Basic state information
puts "Execution state: #{result.state}"
puts "Task completed: #{result.executed?}"

# State in serialized form
result.to_h[:state]  #=> "complete"

# Human-readable inspection
result.to_s
#=> "ProcessOrderTask: type=Task index=0 state=complete status=success outcome=success..."
```

## State-Based Conditional Logic

Use states for execution lifecycle decisions:

```ruby
def handle_task_result(result)
  case result.state
  when "initialized"
    puts "Task not yet started"
  when "executing"
    puts "Task is running..."
    show_progress(result)
  when "complete"
    puts "Task finished normally"
    process_completion(result)
  when "interrupted"
    puts "Task was interrupted"
    handle_interruption(result)
  end
end
```

### Advanced State Logic

```ruby
class TaskMonitor
  def check_results(results)
    results.each do |result|
      # State-based processing
      if result.executing?
        monitor_progress(result)
      elsif result.interrupted?
        analyze_interruption(result)

        # Further analysis based on status
        if result.failed?
          escalate_failure(result)
        elsif result.skipped?
          log_skip_reason(result.metadata[:reason])
        end
      end
    end
  end
end
```

## State Transitions in Complex Workflows

For workflows with multiple tasks, state tracking becomes more complex:

```ruby
class ProcessComplexWorkflowTask < CMDx::Task
  def call
    # Each subtask goes through its own state lifecycle
    first_result = FirstStepTask.call(context)   # states: init -> exec -> complete
    second_result = SecondStepTask.call(context) # states: init -> exec -> complete

    # Main task state reflects its own execution
    context.workflow_completed = true
  end
end

result = ProcessComplexWorkflowTask.call
run = result.run

# Main task state
result.state            #=> "complete"

# Individual task states
run.results[0].state    #=> "complete" (ProcessComplexWorkflowTask)
run.results[1].state    #=> "complete" (FirstStepTask)
run.results[2].state    #=> "complete" (SecondStepTask)
```

## State Persistence and Logging

States are automatically captured in result serialization:

```ruby
result = ProcessOrderTask.call

# Hash representation includes state
result.to_h
#=> {
#     class: "ProcessOrderTask",
#     index: 0,
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     # ... other attributes
#   }

# Run-level state aggregation
result.run.to_h
#=> {
#     id: "run-uuid...",
#     state: "complete",      # Derived from first result
#     status: "success",      # Derived from first result
#     results: [
#       { state: "complete", status: "success", ... },
#       # ... other results
#     ]
#   }
```

## Best Practices

### State Checking

- **Use `executed?`** to check if a task has finished (regardless of outcome)
- **Use `complete?`** to check for successful execution lifecycle completion
- **Use `interrupted?`** to detect execution problems or halts
- **Avoid manual state modification** - states are automatically managed

### Callback Usage

- **Use state callbacks** for lifecycle-based logic (cleanup, monitoring)
- **Combine state and status callbacks** for comprehensive result handling
- **Chain callbacks** for fluent result processing
- **Use `on_executed`** for logic that should run regardless of success/failure

### Monitoring and Debugging

- **Include state information** in logging and monitoring
- **Use state transitions** to track task execution flow
- **Monitor interrupted states** for system health
- **Combine state and status information** for complete execution picture

---

- **Prev:** [Outcomes - Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
- **Next:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
