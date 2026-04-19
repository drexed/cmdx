# Outcomes - States

States track the lifecycle dimension of a result: did `work` run end-to-end, or did something interrupt it? There are exactly two states. Transient stages (`initialized`/`executing`) aren't modeled — `Result` is constructed once, after `Runtime` has finalized the task.

## Definitions

| State | Description |
| ----- | ----------- |
| `complete` | Task finished `work` (and output verification) without any `skip!` / `fail!` / exception. |
| `interrupted` | Task halted via `skip!`, `fail!`, an unrescued `StandardError`, or accumulated `task.errors`. |

State-Status combinations:

| State | Status | Meaning |
| ----- | ------ | ------- |
| `complete` | `success` | Task finished successfully |
| `interrupted` | `skipped` | Task halted via `skip!` |
| `interrupted` | `failed` | Task halted via `fail!`, `throw!`, an exception, or validation/coercion errors |

!!! note

    `complete` only ever pairs with `success`, and `interrupted` only ever pairs with `skipped` or `failed`. There is no `complete` + `skipped` or `interrupted` + `success` combination.

## Predicates

```ruby
result = ProcessVideoUpload.execute

result.complete?    #=> true on success, false otherwise
result.interrupted? #=> true on skip or fail, false otherwise
```

## Handlers

State-based dispatch with `on(:complete)` / `on(:interrupted)`. Pass multiple keys to one call when you want either to match:

```ruby
result = ProcessVideoUpload.execute

result
  .on(:complete)    { |r| send_upload_notification(r) }
  .on(:interrupted) { |r| cleanup_temp_files(r) }

# Run the same handler for either state — useful for cleanup/metrics
result.on(:complete, :interrupted) { |r| log_upload_metrics(r) }
```

!!! warning "Important"

    `on` raises `ArgumentError` for unknown event keys. Valid keys: `:complete`, `:interrupted`, `:success`, `:skipped`, `:failed`, `:ok`, `:ko`.
