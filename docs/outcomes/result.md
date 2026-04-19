# Outcomes - Result

A `Result` is the read-only outcome of a task execution. It exposes the signal (state, status, reason, metadata, cause), the owning chain, the task's context, and lifecycle metadata (retries, duration, rollback, deprecation).

## Result Attributes

!!! note

    Results are immutable. Runtime teardown freezes the `Task`, `Errors`, and — for the root — the `Context` and `Chain`. The backing signal's payload is frozen at construction.

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Identity
result.id          #=> "0190..." (uuid_v7 for this execution)
result.task        #=> BuildApplication              (the task class)
result.type        #=> "Task"                        (or "Workflow")
result.context     #=> #<CMDx::Context ...>          (frozen on root teardown)
result.ctx         #=> alias for #context
result.errors      #=> #<CMDx::Errors ...>           (frozen on teardown)

# Chain placement
result.chain       #=> #<CMDx::Chain ...>
result.chain.id    #=> "0190..."
result.chain_index #=> 0  (root is always 0; children are 1+ in completion order)
result.chain_root? #=> true when this result is the root of its chain

# Signal data
result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Build tool not found"
result.metadata #=> { error_code: "BUILD_TOOL.NOT_FOUND" }
result.cause    #=> nil, the rescued StandardError, or the propagated Fault

# Lifecycle metadata
result.duration     #=> 12.34            (milliseconds, monotonic)
result.retries      #=> 2
result.retried?     #=> true
result.strict?      #=> false            (true when produced via execute!)
result.deprecated?  #=> false
result.rolled_back? #=> false
result.tags         #=> []               (from settings(tags: [...]))
```

## Lifecycle Predicates

```ruby
result = BuildApplication.execute(version: "1.2.3")

# State predicates
result.complete?    #=> true on success
result.interrupted? #=> true on skip or fail

# Status predicates
result.success?     #=> true when status == "success"
result.skipped?     #=> true when status == "skipped"
result.failed?      #=> true when status == "failed"

# Outcome categorization
result.ok?          #=> true for success or skipped
result.ko?          #=> true for skipped or failed
```

!!! note

    There are no `executed?` / `executing?` predicates — a `Result` only exists post-finalization, so every result is by definition already executed.

## Chain Analysis

Failure propagation is tracked as `origin` — the upstream `Result` this one was echoed from (set automatically by `Task#throw!` and by `Runtime` when it rescues a `Fault` inside `work`). The chain helpers all return `nil` when the result isn't `failed?`:

```ruby
result = DeploymentWorkflow.execute(app_name: "webapp")

if result.failed?
  result.origin            #=> immediate upstream Result, or nil if locally originated
  result.threw_failure     #=> origin || self  (nearest upstream failed result)
  result.caused_failure    #=> walks origin recursively to the deepest leaf
  result.caused_failure?   #=> true when this result originated the failure chain (no origin)
  result.thrown_failure?   #=> true when this result re-threw an upstream failure (has an origin)
end
```

For a nested workflow where leaf `ChargeCard` fails inside `PaymentWorkflow`, which is run inside `CheckoutWorkflow`:

| Result              | `origin`           | `threw_failure`    | `caused_failure` | `caused_failure?` | `thrown_failure?` |
|---------------------|--------------------|--------------------|------------------|-------------------|-------------------|
| `ChargeCard`        | `nil`              | `self`             | `self`           | `true`            | `false`            |
| `PaymentWorkflow`   | `ChargeCard`       | `ChargeCard`       | `ChargeCard`     | `false`           | `true`           |
| `CheckoutWorkflow`  | `PaymentWorkflow`  | `PaymentWorkflow`  | `ChargeCard`     | `false`           | `true`           |

`threw_failure` always points one level up; `caused_failure` walks all the way down to the originator.

## Annotating a Successful Result

`success!` halts `work` early with a custom reason and metadata, just like `skip!` / `fail!` — the difference is that the produced signal has `status: "success"` and `state: "complete"`:

```ruby
class ImportRecords < CMDx::Task
  def work
    count = import_all(context.records)
    success!("Imported #{count} records", rows: count)
    # Anything below is unreachable
  end
end

result = ImportRecords.execute(records: data)

result.success? #=> true
result.complete? #=> true
result.reason   #=> "Imported 42 records"
result.metadata #=> { rows: 42 }
```

!!! note

    `success!` `throw`s out of `work` like every other halt method — it is **not** a "set fields without halting" call. To attach metadata mid-`work` without halting, mutate `context` instead.

## Block Yield

`execute` and `execute!` both accept a block; the block receives the result and its return value becomes the call's return value:

```ruby
deploy_url = BuildApplication.execute(version: "1.2.3") do |result|
  if result.success?
    notify_deployment_ready(result)
  elsif result.failed?
    handle_build_failure(result)
  else
    log_skip_reason(result)
  end
end
```

## Predicate Dispatch

`Result#on(*keys, &block)` yields `self` when any key matches a truthy predicate. Returns `self` for chaining:

```ruby
result = BuildApplication.execute(version: "1.2.3")

result
  .on(:success)     { |r| notify_deployment_ready(r) }
  .on(:failed)      { |r| handle_build_failure(r) }
  .on(:skipped)     { |r| log_skip_reason(r) }
  .on(:complete)    { |r| update_build_status(r) }
  .on(:interrupted) { |r| cleanup_partial_artifacts(r) }
  .on(:ok)          { |r| increment_success_counter(r) }   # success or skipped
  .on(:ko)          { |r| alert_operations_team(r) }       # skipped or failed
```

!!! warning "Important"

    `on` requires a block (raises `ArgumentError` otherwise) and accepts only these event keys: `:complete`, `:interrupted`, `:success`, `:skipped`, `:failed`, `:ok`, `:ko`. Unknown keys raise `ArgumentError`.

## Pattern Matching

`Result` supports both array and hash deconstruction (Ruby 3.0+).

### Array Pattern

`deconstruct` returns `[type, task, state, status, reason, metadata, cause, origin]`:

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in [_, _, "complete",    "success", *]                  then redirect_to(build_success_page)
in [_, _, "interrupted", "failed",  reason, *]          then retry_build_with_backoff(result, reason)
in [_, _, "interrupted", "skipped", *]                  then log_skip_and_continue
in ["Workflow", BuildApplication, *]                    then handle_build_workflow(result)
end
```

### Hash Pattern

`deconstruct_keys` exposes:
`:chain_root, :type, :task, :state, :status, :reason, :metadata, :cause, :origin, :strict, :deprecated, :retries, :rolled_back, :duration`.

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in { state: "complete", status: "success" }
  celebrate_build_success
in { status: "failed", metadata: { retryable: true } }
  schedule_build_retry(result)
in { status: "failed", reason: String => reason }
  escalate_build_error("Build failed: #{reason}")
in { chain_root: true, rolled_back: true }
  alert_root_rollback(result)
end
```

### Pattern Guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_build_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_build_permanently_failed(result)
in { duration: Float => ms } if ms > performance_threshold
  investigate_build_performance(result)
end
```

## Serialization

`to_h` returns a memoized hash suitable for telemetry sinks and structured logs. `to_s` is the space-separated `key=value.inspect` rendering that `Runtime` writes to the task logger after `task_executed`.

```ruby
result.to_h
#=> {
#     chain_id: "0190...", chain_index: 0, chain_root: true,
#     type: "Task", task: BuildApplication, id: "0190...",
#     context: #<CMDx::Context ...>,
#     state: "complete", status: "success",
#     reason: nil, metadata: {},
#     strict: false, deprecated: false,
#     retried: false, retries: 0,
#     duration: 12.34, tags: []
#   }

result.to_s
#=> "chain_id=\"0190...\" chain_index=0 ... state=\"complete\" status=\"success\" ..."
```

On `failed?` results, `to_h` additionally includes `:cause`, `:origin`, `:threw_failure`, `:caused_failure`, and `:rolled_back`. The `_failure` and `:origin` entries are compact `{ task:, id: }` hashes (and render as `<TaskClass uuid>` in `to_s`) to avoid serializing entire upstream results. `:origin` is `nil` when the failure is locally originated.
