# Outcomes - States

States represent the execution lifecycle condition of task execution, tracking
the progress of tasks through their complete execution journey. States provide
insight into where a task is in its lifecycle and enable lifecycle-based
decision making and monitoring.

## Table of Contents

- [TLDR](#tldr)
- [State Definitions](#state-definitions)
- [State Transitions](#state-transitions)
- [State Predicates](#state-predicates)
- [State-Based Callbacks](#state-based-callbacks)
- [State vs Status Distinction](#state-vs-status-distinction)
- [State Inspection and Monitoring](#state-inspection-and-monitoring)
- [State Persistence and Logging](#state-persistence-and-logging)

## TLDR

- **States** - Track execution lifecycle: `initialized` → `executing` → `complete`/`interrupted`
- **Automatic** - States are managed automatically by the framework, never modify manually
- **Predicates** - Check with `result.complete?`, `result.interrupted?`, `result.executed?`
- **Callbacks** - Use `.on_complete`, `.on_interrupted`, `.on_executed` for lifecycle events
- **vs Status** - State = where in lifecycle, Status = how execution ended

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

> [!IMPORTANT]
> States are automatically managed during task execution and should **never** be modified manually. State transitions are handled internally by the CMDx framework.

### Automatic State Management

States are automatically managed during task execution and should **never** be modified manually:

```ruby
task = ProcessUserOrderTask.new
task.result.state #=> "initialized"

# During task execution, states transition automatically:
# 1. initialized -> executing (when call begins)
# 2. executing -> complete (successful completion)
# 3. executing -> interrupted (on failure/halt)

result = ProcessUserOrderTask.call
result.state #=> "complete" (if successful)
```

### State Transition Methods (Internal Use)

These methods handle state transitions internally and are not intended for direct use:

```ruby
result = ProcessUserOrderTask.new.result

# Internal state transition methods
result.executing!   # initialized -> executing
result.complete!    # executing -> complete
result.interrupt!   # executing -> interrupted
result.executed!    # executing -> complete OR interrupted (based on status)
```

> [!WARNING]
> State transition methods (`executing!`, `complete!`, `interrupt!`) are for internal framework use only. Never call these methods directly in your application code.

## State Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = ProcessUserOrderTask.call

# Check current state
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# Combined state checking
result.executed?    #=> true (complete OR interrupted)
```

## State-Based Callbacks

Results provide callback methods for state-based conditional execution:

```ruby
result = ProcessUserOrderTask.call

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
ProcessUserOrderTask
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

> [!TIP]
> Use state-based callbacks for lifecycle event handling. The `on_executed` callback is particularly useful for cleanup operations that should run regardless of success or failure.

## State vs Status Distinction

Understanding the difference between states and statuses is crucial:

- **State**: Execution lifecycle position (`initialized` → `executing` → `complete`/`interrupted`)
- **Status**: Execution outcome (`success`, `skipped`, `failed`)

```ruby
result = ProcessUserOrderTask.call

# State indicates WHERE in the lifecycle
result.state    #=> "complete" (finished executing)

# Status indicates HOW the execution ended
result.status   #=> "success" (executed successfully)

# Both can be different for interrupted tasks
failed_result = ProcessFailingOrderTask.call
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

> [!NOTE]
> State tracks the execution lifecycle (where the task is), while status tracks the outcome (how the task ended). Both provide valuable but different information about task execution.

## State Inspection and Monitoring

States provide valuable information for monitoring and debugging:

```ruby
result = ProcessUserOrderTask.call

# Basic state information
puts "Execution state: #{result.state}"
puts "Task completed: #{result.executed?}"

# State in serialized form
result.to_h[:state]  #=> "complete"

# Human-readable inspection
result.to_s
#=> "ProcessUserOrderTask: type=Task index=0 state=complete status=success outcome=success..."
```

## State Persistence and Logging

States are automatically captured in result serialization:

```ruby
result = ProcessUserOrderTask.call

# Hash representation includes state
result.to_h
#=> {
#     class: "ProcessUserOrderTask",
#     index: 0,
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     # ... other attributes
#   }

# Chain-level state aggregation
result.chain.to_h
#=> {
#     id: "chain-uuid...",
#     state: "complete",      # Derived from first result
#     status: "success",      # Derived from first result
#     results: [
#       { state: "complete", status: "success", ... },
#       # ... other results
#     ]
#   }
```

---

- **Prev:** [Outcomes - Statuses](statuses.md)
- **Next:** [Parameters - Definitions](../parameters/definitions.md)
