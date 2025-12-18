# Outcomes - States

States track where a task is in its execution lifecycle—from creation through completion or interruption.

## Definitions

| State         | Description                                                                    |
| ------------- | ------------------------------------------------------------------------------ |
| `initialized` | Task created but execution not yet started. Default state for new tasks.       |
| `executing`   | Task is actively running its business logic. Transient state during execution. |
| `complete`    | Task finished execution successfully without any interruption or halt.         |
| `interrupted` | Task execution was stopped due to a fault, exception, or explicit halt.        |

State-Status combinations:

| State         | Status    | Meaning                             |
| ------------- | --------- | ----------------------------------- |
| `initialized` | `success` | Task created, not yet executed      |
| `executing`   | `success` | Task currently running              |
| `complete`    | `success` | Task finished successfully          |
| `complete`    | `skipped` | Task finished by skipping execution |
| `interrupted` | `failed`  | Task stopped due to failure         |
| `interrupted` | `skipped` | Task stopped by skip condition      |

## Transitions

Caution

States are managed automatically—never modify them manually.

```ruby
# Valid state transition flow
initialized → executing → complete    (successful execution)
initialized → executing → interrupted (skipped/failed execution)
```

## Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = ProcessVideoUpload.execute

# Individual state checks
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# State categorization
result.executed?    #=> true (complete OR interrupted)
```

## Handlers

Handle lifecycle events with state-based handlers. Use `on(:executed)` for cleanup that runs regardless of outcome:

```ruby
result = ProcessVideoUpload.execute

# Individual state handlers
result
  .on(:complete) { |result| send_upload_notification(result) }
  .on(:interrupted) { |result| cleanup_temp_files(result) }
  .on(:executed) { |result| log_upload_metrics(result) } #=> .on(:complete, :interrupted)
```
