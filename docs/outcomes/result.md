# Outcomes - Result

When a task finishes, you get a **`Result`**—a read-only snapshot of what happened. It bundles the **signal** (state, status, reason, metadata, cause), where this task sits in its **chain**, the task’s **context**, and a few **lifecycle stats** (retries, how long it took, rollback flags, deprecation).

If `Result` were a receipt, everything on it would be printed in ink: no edits after the fact.

## Result attributes

!!! note

    Results are immutable. When Runtime tears down, it freezes the `Task`, `Errors`, and—for the root—the `Context` and `Chain`. The signal’s payload freezes when the result is built.

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Identity
result.tid         #=> "0190..." (uuid_v7 for this execution)
result.task        #=> BuildApplication              (the task class)
result.type        #=> "Task"                        (or "Workflow")
result.context     #=> #<CMDx::Context ...>          (frozen on root teardown)
result.ctx         #=> alias for #context
result.errors      #=> #<CMDx::Errors ...>           (frozen on teardown)

# Chain placement
result.chain       #=> #<CMDx::Chain ...>
result.cid         #=> "0190..."
result.xid         #=> "abc-123-..." or nil (external correlation id, see Configuration)
result.index       #=> 0  (root is always 0; children are 1+ in completion order)
result.root?       #=> true when this result is the root of its chain

# Signal data
result.state        #=> "interrupted"
result.status       #=> "failed"
result.reason       #=> "Build tool not found"
result.metadata     #=> { error_code: "BUILD_TOOL.NOT_FOUND" }
result.cause        #=> nil, the rescued StandardError, or the propagated Fault
result.backtrace    #=> caller_locations captured by fail!/throw! (Array<Thread::Backtrace::Location>), or nil
                    #   (Fault#backtrace stringifies these through the configured backtrace_cleaner)

# Lifecycle metadata
result.duration     #=> 12.34            (milliseconds, monotonic)
result.retries      #=> 2
result.retried?     #=> true
result.strict?      #=> false            (true when produced via execute! or execute(strict: true))
result.deprecated?  #=> false
result.rolled_back? #=> false
result.tags         #=> []               (from settings(tags: [...]))
```

## Lifecycle predicates

```ruby
result = BuildApplication.execute(version: "1.2.3")

# State predicates
result.complete?    #=> true on success
result.interrupted? #=> true on skip or fail

# Status predicates
result.success?     #=> true when status == "success"
result.skipped?     #=> true when status == "skipped"
result.failed?      #=> true when status == "failed"

# Outcome buckets
result.ok?          #=> true for success or skipped
result.ko?          #=> true for skipped or failed
```

!!! note

    There is no `executing?` here. A `Result` only appears **after** things are finalized—so “already ran” is baked in.

## Chain analysis: who broke what? {#chain-analysis}

When failures bubble, CMDx remembers **`origin`**—the upstream `Result` yours echoed (via `Task#throw!` or Runtime rescuing a `Fault` inside `work`). The helpers below only make sense when `result.failed?`; otherwise they return `nil`:

```ruby
result = DeploymentWorkflow.execute(app_name: "webapp")

if result.failed?
  result.origin            #=> immediate upstream Result, or nil if this task started the mess
  result.threw_failure     #=> origin || self  (nearest upstream failed result)
  result.caused_failure    #=> walks origin recursively to the deepest leaf
  result.caused_failure?   #=> true when this result started the failure chain (no origin)
  result.thrown_failure?   #=> true when this result passed someone else’s failure along (has origin)
end
```

Picture a nested workflow: `ChargeCard` fails inside `PaymentWorkflow`, which sits inside `CheckoutWorkflow`:

| Result              | `origin`           | `threw_failure`    | `caused_failure` | `caused_failure?` | `thrown_failure?` |
|---------------------|--------------------|--------------------|------------------|-------------------|-------------------|
| `ChargeCard`        | `nil`              | `self`             | `self`           | `true`            | `false`            |
| `PaymentWorkflow`   | `ChargeCard`       | `ChargeCard`       | `ChargeCard`     | `false`           | `true`           |
| `CheckoutWorkflow`  | `PaymentWorkflow`  | `PaymentWorkflow`  | `ChargeCard`     | `false`           | `true`           |

- **`threw_failure`** is the nearest failed neighbor (`origin` if there is one, otherwise `self` for whoever started it).
- **`caused_failure`** keeps walking `origin` until it hits the task that actually broke first.

## Annotating a successful result

`success!` stops `work` early like `skip!` and `fail!`—except the signal says **`status: "success"`** and **`state: "complete"`**:

```ruby
class ImportRecords < CMDx::Task
  def work
    count = import_all(context.records)
    success!("Imported #{count} records", rows: count)
    # Code below never runs
  end
end

result = ImportRecords.execute(records: data)

result.success? #=> true
result.complete? #=> true
result.reason   #=> "Imported 42 records"
result.metadata #=> { rows: 42 }
```

!!! note

    `success!` **throws** out of `work`, same family as the other halt helpers—it is not a quiet “set fields and keep going.” Need metadata mid-flight without stopping? Put it on `context`.

## Block yield

Both `execute` and `execute!` can take a block. The block receives the result; whatever the block returns becomes the return value of the call:

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

## Predicate dispatch with `on` {#predicate-dispatch}

`Result#on(*keys, &block)` runs your block when **any** listed predicate is truthy. It returns `self` so you can chain:

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

!!! warning "Heads up"

    You **must** pass a block (otherwise `ArgumentError`). Keys must be one of `:complete`, `:interrupted`, `:success`, `:skipped`, `:failed`, `:ok`, `:ko`. Anything else raises `ArgumentError`.

## Pattern matching

Ruby 3.0+ can destructure a `Result` as arrays or hashes.

### Array pattern

`deconstruct` returns `to_h.to_a`—`[key, value]` pairs in order. Find-patterns let you match specific entries without caring about position:

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result.deconstruct
in [*, [:status, "success"], *]                      then redirect_to(build_success_page)
in [*, [:status, "failed"], *, [:reason, reason], *] then retry_build_with_backoff(result, reason)
in [*, [:status, "skipped"], *]                      then log_skip_and_continue
in [*, [:type, "Workflow"], *]                       then handle_build_workflow(result)
end
```

### Hash pattern

`deconstruct_keys(keys)` delegates to `#to_h`. Pass `nil` for the whole hash, or a list of keys for a slice (unknown keys disappear).

Keys you can usually count on: `:xid, :cid, :index, :root, :type, :task, :tid, :context, :state, :status, :reason, :metadata, :strict, :deprecated, :retried, :retries, :duration, :tags`.

Failure-only keys (`:cause`, `:origin`, `:threw_failure`, `:caused_failure`, `:rolled_back`) show up when `failed?` is true.

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in { state: "complete", status: "success" }
  celebrate_build_success
in { status: "failed", metadata: { retryable: true } }
  schedule_build_retry(result)
in { status: "failed", reason: String => reason }
  escalate_build_error("Build failed: #{reason}")
in { root: true, rolled_back: true }
  alert_root_rollback(result)
end
```

### Pattern guards

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

- **`to_h`** — memoized hash for logs and telemetry.
- **`as_json`** — same as `to_h` for Rails-style callers.
- **`to_json`** — uses the stdlib `json` gem.
- **`to_s`** — space-separated `key=value.inspect` line Runtime logs after `task_executed`.

```ruby
result.to_h
#=> {
#     xid: "abc-123-..." or nil,
#     cid: "0190...", index: 0, root: true,
#     type: "Task", task: BuildApplication, tid: "0190...",
#     context: #<CMDx::Context ...>,
#     state: "complete", status: "success",
#     reason: nil, metadata: {},
#     strict: false, deprecated: false,
#     retried: false, retries: 0,
#     duration: 12.34, tags: []
#   }

result.as_json           #=> same hash as to_h
result.to_json           #=> '{"xid":null,"cid":"0190...",...}'
result.to_s
#=> "xid=nil cid=\"0190...\" index=0 ... state=\"complete\" status=\"success\" ..."
```

For failed results, `to_h` also adds `:cause`, `:origin`, `:threw_failure`, `:caused_failure`, and `:rolled_back`. The `_failure` fields and `:origin` are compact `{ task:, tid: }` hashes (and `to_s` renders tasks as `<TaskClass uuid>`) so you do not serialize giant upstream trees. `:origin` is `nil` when the failure started here.

!!! note

    `to_json` uses each object’s default JSON rules—Classes, exceptions, nested `Context`, etc. Symbol keys become strings in JSON output.
