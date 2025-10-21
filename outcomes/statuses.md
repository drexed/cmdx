# Outcomes - Statuses

Statuses represent the business outcome of task execution logic, indicating how the task's business logic concluded. Statuses differ from execution states by focusing on the business outcome rather than the technical execution lifecycle. Understanding statuses is crucial for implementing proper business logic branching and error handling.

## Table of Contents

- [Definitions](#definitions)
- [Transitions](#transitions)
- [Predicates](#predicates)
- [Handlers](#handlers)

## Definitions

| Status | Description |
| ------ | ----------- |
| `success` | Task execution completed successfully with expected business outcome. Default status for all tasks. |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary. |
| `failed` | Task stopped execution due to business rule violations, validation errors, or exceptions. |

## Transitions

> [!IMPORTANT]
> Status transitions are unidirectional and final. Once a task is marked as skipped or failed, it cannot return to success status. Design your business logic accordingly.

```ruby
# Valid status transitions
success → skipped    # via skip!
success → failed     # via fail! or exception

# Invalid transitions (will raise errors)
skipped → success    # ❌ Cannot transition
skipped → failed     # ❌ Cannot transition
failed → success     # ❌ Cannot transition
failed → skipped     # ❌ Cannot transition
```

## Predicates

Use status predicates to check execution outcomes:

```ruby
result = ProcessNotification.execute

# Individual status checks
result.success? #=> true/false
result.skipped? #=> true/false
result.failed?  #=> true/false

# Outcome categorization
result.good?    #=> true if success OR skipped
result.bad?     #=> true if skipped OR failed (not success)
```

## Handlers

Use status-based handlers for business logic branching. The `on_good` and `on_bad` handlers are particularly useful for handling success/skip vs failed outcomes respectively.

```ruby
result = ProcessNotification.execute

# Individual status handlers
result
  .handle_success { |result| mark_notification_sent(result) }
  .handle_skipped { |result| log_notification_skipped(result) }
  .handle_failed { |result| queue_retry_notification(result) }

# Outcome-based handlers
result
  .handle_good { |result| update_message_stats(result) }
  .handle_bad { |result| track_delivery_failure(result) }
```

---

- **Prev:** [Outcomes - States](states.md)
- **Next:** [Attributes - Definitions](../attributes/definitions.md)
