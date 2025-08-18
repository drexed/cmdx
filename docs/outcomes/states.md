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
- [State Persistence and Logging](#state-persistence-and-logging)

## TLDR

```ruby
# Check execution lifecycle
result.initialized?  #=> false (after execution)
result.executing?    #=> false (after execution)
result.complete?     #=> true (successful completion)
result.interrupted?  #=> false (no interruption)
result.executed?     #=> true (complete OR interrupted)

# State-based callbacks
result
  .on_complete { |r| send_confirmation_email(r.context) }
  .on_interrupted { |r| log_error_and_retry(r) }
  .on_executed { |r| cleanup_resources(r) }

# States: WHERE in lifecycle, Status: HOW it ended
result.state   #=> "complete" (finished executing)
result.status  #=> "success" (executed successfully)
```

## State Definitions

> [!IMPORTANT]
> States are automatically managed during task execution and should **never** be modified manually. State transitions are handled internally by the CMDx framework.

| State | Description |
| ----- | ----------- |
| `initialized` | Task created but execution not yet started. Default state for new tasks. |
| `executing` | Task is actively running its business logic. Transient state during execution. |
| `complete` | Task finished execution successfully without any interruption or halt. |
| `interrupted` | Task execution was stopped due to a fault, exception, or explicit halt. |

## State Transitions

States follow a strict lifecycle with controlled transitions:

```ruby
# Valid state transition flow
initialized → executing → complete    (successful execution)
initialized → executing → interrupted (failed/halted execution)
```

### Automatic State Management

```ruby
class ProcessPayment < CMDx::Task
  def work
    # State automatically managed:
    # 1. initialized → executing (when call begins)
    # 2. executing → complete (successful completion)
    # 3. executing → interrupted (on failure/halt)

    charge_customer(amount)
    send_receipt(email)
  end
end

task = ProcessPaymentTask.new
task.result.state #=> "initialized"

result = ProcessPaymentTask.call
result.state #=> "complete" (if successful)
```

### Internal State Transition Methods

> [!WARNING]
> State transition methods (`executing!`, `complete!`, `interrupt!`) are for internal framework use only. Never call these methods directly in your application code.

```ruby
result = ProcessPaymentTask.new.result

# Internal state transition methods (DO NOT USE)
result.executing!   # initialized → executing
result.complete!    # executing → complete
result.interrupt!   # executing → interrupted
result.executed!    # executing → complete OR interrupted (based on status)
```

## State Predicates

Use state predicates to check the current execution lifecycle:

```ruby
class OrderFulfillment < CMDx::Task
  def work
    process_order
    ship_items
  end
end

result = OrderFulfillmentTask.call

# Check current state
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# Combined state checking
result.executed?    #=> true (complete OR interrupted)
```

### State Checking in Conditional Logic

```ruby
def handle_task_result(result)
  if result.complete?
    notify_success(result.context)
  elsif result.interrupted?
    handle_failure(result.metadata)
  end

  # Always cleanup when execution finished
  cleanup_resources if result.executed?
end
```

## State-Based Callbacks

> [!TIP]
> Use state-based callbacks for lifecycle event handling. The `on_executed` callback is particularly useful for cleanup operations that should run regardless of success or failure.

```ruby
class ProcessOrder < CMDx::Task
  def work
    validate_inventory
    charge_payment
    update_stock
  end
end

result = ProcessOrderTask.call

# Individual state callbacks
result
  .on_complete { |r| send_confirmation_email(r.context.customer_email) }
  .on_interrupted { |r| log_error(r.metadata) && schedule_retry(r) }
  .on_executed { |r| update_analytics(r.runtime) }
```

### Advanced Callback Patterns

```ruby
ProcessOrderTask
  .execute(order_id: 123)
  .on_complete { |result|
    # Only runs if task completed successfully
    OrderMailer.confirmation(result.context.order).deliver_now
    Analytics.track("order_processed", order_id: result.context.order_id)
  }
  .on_interrupted { |result|
    # Only runs if task was interrupted
    ErrorLogger.log(result.metadata[:error])

    if result.metadata[:retryable]
      RetryWorker.perform_later(result.context.order_id)
    end
  }
  .on_executed { |result|
    # Always runs after execution (complete OR interrupted)
    PerformanceTracker.record(result.runtime)
    TempFileCleanup.perform(result.context.temp_files)
  }
```

## State vs Status Distinction

> [!NOTE]
> State tracks the execution lifecycle (where the task is), while status tracks the outcome (how the task ended). Both provide valuable but different information about task execution.

Understanding the difference between states and statuses is crucial:

- **State**: Execution lifecycle position (`initialized` → `executing` → `complete`/`interrupted`)
- **Status**: Execution outcome (`success`, `skipped`, `failed`)

```ruby
class ProcessRefund < CMDx::Task
  def work
    return unless eligible_for_refund?

    process_refund
    notify_customer
  end
end

# Successful execution
result = ProcessRefundTask.call
result.state    #=> "complete" (finished executing)
result.status   #=> "success" (executed successfully)

# Failed execution
failed_result = ProcessRefund.execute(invalid_order_id: "xyz")
failed_result.state   #=> "interrupted" (execution stopped)
failed_result.status  #=> "failed" (outcome was failure)
```

### State-Status Combinations

| State | Status | Meaning |
| ----- | ------ | ------- |
| `initialized` | `success` | Task created, not yet executed |
| `executing` | `success` | Task currently running |
| `complete` | `success` | Task finished successfully |
| `complete` | `skipped` | Task finished by skipping execution |
| `interrupted` | `failed` | Task stopped due to failure |
| `interrupted` | `skipped` | Task stopped by skip condition |

## State Persistence and Logging

> [!IMPORTANT]
> States are automatically captured in result serialization and logging. All state information persists through the complete task execution lifecycle.

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
#     runtime: 0.045,
#     metadata: {},
#     context: { order_id: 123 }
#   }

# Human-readable inspection
result.to_s
#=> "ProcessOrderTask: type=Task index=0 state=complete status=success outcome=success runtime=0.045s"

# Chain-level state aggregation
result.chain.to_h
#=> {
#     id: "chain-550e8400-e29b-41d4-a716-446655440000",
#     state: "complete",      # Derived from overall chain state
#     status: "success",      # Derived from overall chain status
#     results: [
#       { state: "complete", status: "success", ... },
#       { state: "complete", status: "success", ... }
#     ]
#   }
```

---

- **Prev:** [Outcomes - Statuses](statuses.md)
- **Next:** [Parameters - Definitions](../parameters/definitions.md)
