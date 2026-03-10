# Result Reference

For full documentation, see [docs/outcomes/result.md](../docs/outcomes/result.md), [docs/outcomes/states.md](../docs/outcomes/states.md), [docs/outcomes/statuses.md](../docs/outcomes/statuses.md).

## Attributes

```ruby
result.task           # CMDx::Task instance
result.context        # CMDx::Context (delegated from task)
result.chain          # CMDx::Chain (delegated from task)
result.errors         # CMDx::Errors (delegated from task)
result.state          # String: "initialized", "executing", "complete", "interrupted"
result.status         # String: "success", "skipped", "failed"
result.reason         # String or nil — skip/fail reason
result.cause          # Exception or nil — originating exception
result.metadata       # Hash — arbitrary metadata from skip!/fail!/throw!
result.retries        # Integer — number of retry attempts
result.index          # Integer — position in chain
result.outcome        # String — unified outcome (status or state depending on context)
```

## State and Status Matrix

| State | Status | `complete?` | `interrupted?` | `executed?` | `success?` | `skipped?` | `failed?` | `good?` | `bad?` |
|-------|--------|-------------|----------------|-------------|------------|------------|-----------|---------|--------|
| `complete` | `success` | true | false | true | true | false | false | true | false |
| `interrupted` | `skipped` | false | true | true | false | true | false | true | true |
| `interrupted` | `failed` | false | true | true | false | false | true | false | true |

Key nuance: **skipped is both `good?` and `bad?`**. `good?` means "not failed" (`!failed?`). `bad?` means "not success" (`!success?`).

`ok?` is an alias for `good?`.

## Handlers

The `on` method takes one or more state/status symbols and yields if any match:

```ruby
result
  .on(:success) { |r| process_success(r) }
  .on(:failed)  { |r| handle_failure(r) }
  .on(:skipped) { |r| log_skip(r) }
```

### Available handler symbols

| Symbol | Matches when |
|--------|-------------|
| `:success` | `success?` is true |
| `:skipped` | `skipped?` is true |
| `:failed` | `failed?` is true |
| `:complete` | `complete?` is true |
| `:interrupted` | `interrupted?` is true |
| `:executed` | `executed?` is true (complete OR interrupted) |
| `:good` | `good?` is true (success OR skipped) |
| `:ok` | alias for `:good` |
| `:bad` | `bad?` is true (skipped OR failed) |

Multiple symbols in one call act as OR:

```ruby
result.on(:success, :complete) { |r| ... }
```

Handlers return `self` for chaining. Raises `ArgumentError` if no block given.

## Pattern Matching

### Array deconstruction

Returns `[state, status, reason, cause, metadata]`:

```ruby
case result
in ["complete", "success"]
  handle_success
in ["interrupted", "failed"]
  handle_failure
in ["interrupted", "skipped"]
  handle_skip
end
```

### Hash deconstruction

Available keys: `state`, `status`, `reason`, `cause`, `metadata`, `outcome`, `executed`, `good`, `bad`:

```ruby
case result
in { state: "complete", status: "success" }
  celebrate
in { status: "failed", metadata: { retryable: true } }
  schedule_retry(result)
in { bad: true, metadata: { reason: String => reason } }
  escalate(reason)
end
```

### With guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_permanently_failed(result)
end
```

## Chain Analysis

When tasks are nested (via `throw!`), the chain tracks provenance:

```ruby
result = Workflow.execute(data: input)

if result.failed?
  # The original task that caused the failure (deepest in chain)
  original = result.caused_failure
  original.task.class.name   #=> "InnerTask"
  original.reason            #=> "Validation failed"

  # The task that propagated (threw) the failure
  thrower = result.threw_failure
  thrower.task.class.name    #=> "MiddleTask"

  # Classification predicates
  result.caused_failure?     # true if this result was the original cause
  result.threw_failure?      # true if this result threw a failure from another
  result.thrown_failure?     # true if this result received a thrown failure (failed? && !caused_failure?)
end
```

### Metadata for nested failures

When the Executor logs/formats failures, metadata includes:

```ruby
result.metadata[:threw_failure]   #=> { index: 1, class: "MiddleTask", id: "..." }
result.metadata[:caused_failure]  #=> { index: 2, class: "InnerTask", id: "..." }
```

## Retry Info

```ruby
result.retries   #=> 2 (number of retry attempts)
result.retried?  #=> true (retries > 0)
```

## Rollback Info

```ruby
result.rolled_back?  #=> true (rollback method was called)
```

## Dry Run

```ruby
result.dry_run?  #=> true (delegated to task, which delegates to chain)
```

## Block Yield

Both `execute` and `execute!` accept blocks:

```ruby
MyTask.execute(data: input) do |result|
  if result.success?
    process(result.context)
  end
end
```

## Serialization

```ruby
result.to_h
#=> {
#     state: "interrupted",
#     status: "failed",
#     outcome: "failed",
#     metadata: { error_code: "NOT_FOUND" },
#     reason: "Record not found",
#     cause: #<CMDx::FailFault>,
#     rolled_back: false,
#     threw_failure: { index: 1, class: "MiddleTask", id: "abc" },
#     caused_failure: { index: 2, class: "InnerTask", id: "def" }
#   }

result.to_s
#=> "state=interrupted status=failed reason=\"Record not found\" ..."
```

## Immutability

Results are frozen after execution when `freeze_results: true` (default). Attempting to modify context or metadata after freeze raises an error. Set `freeze_results: false` in configuration if post-execution mutation is needed.
