# Outcomes - Statuses

Statuses represent the business outcome—did the task succeed, skip, or fail? This differs from state, which tracks the execution lifecycle.

## Definitions

| Status | Description |
| ------ | ----------- |
| `success` | Task execution completed successfully with expected business outcome. Default status for all tasks. |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary. |
| `failed` | Task stopped execution due to business rule violations, validation errors, or exceptions. |

## Transitions

!!! warning "Important"

    Status transitions are final and unidirectional. Once skipped or failed, tasks can't return to success.

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

Branch business logic with status-based handlers. Use `on(:good)` and `on(:bad)` for success/skip vs failed outcomes:

```ruby
result = ProcessNotification.execute

# Individual status handlers
result
  .on(:success) { |result| mark_notification_sent(result) }
  .on(:skipped) { |result| log_notification_skipped(result) }
  .on(:failed){ |result| queue_retry_notification(result) }

# Outcome-based handlers
result
  .on(:good) { |result| update_message_stats(result) }  #=> .on(:success, :skipped)
  .on(:bad) { |result| track_delivery_failure(result) } #=> .on(:failed, :skipped)
```
