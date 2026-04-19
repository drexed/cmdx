# Outcomes - Statuses

Statuses represent the business outcome — did the task succeed, skip, or fail? This is independent of state, which only tracks whether the lifecycle ran to completion or was interrupted.

## Definitions

| Status | Description |
| ------ | ----------- |
| `success` | Task `work` ran to completion (and any declared outputs verified). Default outcome. |
| `skipped` | Task halted via `skip!`. Treated as a non-failure outcome. |
| `failed`  | Task halted via `fail!`, `throw!`, an unrescued `StandardError`, or accumulated `task.errors`. |

!!! note

    `throw!` isn't a primitive halt — it re-throws a peer's already-`failed?` result through the current task. See [Fault Propagation](../interruptions/faults.md#fault-propagation).

## Single Final Status

Statuses don't transition. The first `skip!` / `fail!` inside `work` throws out of the call stack, so the result is built once with a single, final status:

```ruby
def work
  fail!("first")    # Runtime catches this and finalizes the result
  skip!("second")   # Unreachable
end
```

!!! note

    Calling `skip!` or `fail!` on a frozen task (after `Runtime` teardown) raises `FrozenError` — they can't mutate a finalized result.

## Predicates

```ruby
result = ProcessNotification.execute

# Direct status checks
result.success? #=> true / false
result.skipped? #=> true / false
result.failed?  #=> true / false

# Outcome categorization
result.ok?      #=> true for success and skipped (anything but failed)
result.ko?      #=> true for skipped and failed (anything but success)
```

!!! note

    `skipped` is intentionally both `ok?` and `ko?`. It's a valid outcome (`ok` — nothing broke) and a non-success (`ko` — work wasn't done). Use `success?` when you need a strict success check.

## Handlers

Branch business logic with status-based handlers. `:ok` and `:ko` are first-class event keys — not aliases of any combination:

```ruby
result = ProcessNotification.execute

# Direct status handlers
result
  .on(:success) { |r| mark_notification_sent(r) }
  .on(:skipped) { |r| log_notification_skipped(r) }
  .on(:failed)  { |r| queue_retry_notification(r) }

# Outcome-based handlers
result
  .on(:ok) { |r| update_message_stats(r) }      # success or skipped
  .on(:ko) { |r| track_delivery_failure(r) }    # skipped or failed
```
