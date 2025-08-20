# Outcomes - States

States represent the execution lifecycle condition of task execution, tracking
the progress of tasks through their complete execution journey. States provide
insight into where a task is in its lifecycle and enable lifecycle-based
decision making and monitoring.

## Table of Contents

- [Definitions](#definitions)
- [Transitions](#transitions)
- [Predicates](#predicates)
- [Handlers](#handlers)

## Definitions

| State | Description |
| ----- | ----------- |
| `initialized` | Task created but execution not yet started. Default state for new tasks. |
| `executing` | Task is actively running its business logic. Transient state during execution. |
| `complete` | Task finished execution successfully without any interruption or halt. |
| `interrupted` | Task execution was stopped due to a fault, exception, or explicit halt. |

State-Status combinations:

| State | Status | Meaning |
| ----- | ------ | ------- |
| `initialized` | `success` | Task created, not yet executed |
| `executing` | `success` | Task currently running |
| `complete` | `success` | Task finished successfully |
| `complete` | `skipped` | Task finished by skipping execution |
| `interrupted` | `failed` | Task stopped due to failure |
| `interrupted` | `skipped` | Task stopped by skip condition |

## Transitions

> [!IMPORTANT]
> States are automatically managed during task execution and should **never** be modified manually. State transitions are handled internally by the CMDx framework.

```ruby
# Valid state transition flow
initialized → executing → complete    (successful execution)
initialized → executing → interrupted (skipped/failed execution)
```

## Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = OrderFulfillment.execute

# Individual state checks
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# State categorization
result.executed?    #=> true (complete OR interrupted)
```

## Handlers

Use state-based handlers for lifecycle event handling. The `on_executed` handler is particularly useful for cleanup operations that should run regardless of success, skipped, or failure.

```ruby
result = ProcessOrder.execute

# Individual state handlers
result
  .on_complete { |result| send_confirmation_email(result) }
  .on_interrupted { |result| schedule_retry(result) }
  .on_executed { |result| update_analytics(result) }
```

---

- **Prev:** [Outcomes - Statuses](statuses.md)
- **Next:** [Attributes - Definitions](../attributes/definitions.md)
