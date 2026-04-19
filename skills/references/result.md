# Result Reference

Docs: [docs/outcomes/result.md](../../docs/outcomes/result.md), [docs/outcomes/states.md](../../docs/outcomes/states.md), [docs/outcomes/statuses.md](../../docs/outcomes/statuses.md).

A `Result` is the frozen outcome of running a task. It's the only value returned by `execute` (and `execute!` when no fault is raised).

## States

Exactly two values (`CMDx::Signal::STATES`):

| State | Predicate | Meaning |
|-------|-----------|---------|
| `"complete"` | `complete?` | `work` finished normally (no halting signal). |
| `"interrupted"` | `interrupted?` | `work` was halted by `skip!` / `fail!` / `throw!` or by accumulated errors. |

## Statuses

Exactly three values (`CMDx::Signal::STATUSES`):

| Status | Predicate | Derived from |
|--------|-----------|--------------|
| `"success"` | `success?` | reached end of `work` (or `success!`). |
| `"skipped"` | `skipped?` | `skip!`. |
| `"failed"`  | `failed?`  | `fail!`, `throw!(failed)`, error accumulation, or rescued non-`Fault` `StandardError`. |

Convenience predicates:

- `ok?` — `success?` or `skipped?` ("not failed").
- `ko?` — `skipped?` or `failed?` ("not success").

## State / status matrix

| State | Statuses allowed |
|-------|------------------|
| `complete` | `success` |
| `interrupted` | `skipped`, `failed` |

`complete` + `failed` / `interrupted` + `success` never occur.

## Data surface

| Accessor | Description |
|----------|-------------|
| `task` | Task **class** that ran. |
| `type` | `"Task"` or `"Workflow"`. |
| `id` | UUID v7 for this execution. |
| `context` | Shared `Context` (frozen on root). |
| `errors` | `Errors` container (frozen). |
| `state`, `status` | Strings. |
| `reason` | String passed to `success!`/`skip!`/`fail!`, `errors.to_s`, or `nil`. |
| `metadata` | Frozen Hash. |
| `cause` | Rescued `StandardError` (or `nil`). Set when `execute!` re-raises. |
| `origin` | Upstream failed `Result` this was echoed from (via `throw!` or rescued `Fault`), or `nil`. |
| `backtrace` | Array of frames captured by `fail!`/`throw!`, cleaned. |
| `retries` / `retried?` | Integer count + boolean. |
| `duration` | Float ms. |
| `strict?` | `true` when produced via `execute!`. |
| `deprecated?` | `true` when the class has a fired deprecation. |
| `rolled_back?` | `true` when `#rollback` ran. |
| `tags` | `task.settings.tags`. |
| `chain` | `CMDx::Chain`. |
| `chain_index` | Position in chain (Integer or `nil`). |
| `chain_root?` | `true` for the outermost result in the chain. |

## Chain analysis

```ruby
result.caused_failure    # deepest failed Result; self when originator; nil unless failed?
result.threw_failure     # nearest upstream failed Result; self when originator; nil unless failed?
result.caused_failure?   # failed? && origin.nil?
result.thrown_failure?   # failed? && !origin.nil?
```

`origin` walks one level; `caused_failure` walks recursively to the leaf. For a root-level failure, `caused_failure == threw_failure == self`.

## Handlers

```ruby
result
  .on(:success)     { |r| redirect_to(dashboard) }
  .on(:skipped)     { |r| log_skip(r.reason) }
  .on(:failed)      { |r| render_error(r.reason) }
  .on(:complete)    { |r| audit(r) }
  .on(:interrupted) { |r| notify(r) }
  .on(:ok)          { |r| track(r) }
  .on(:ko)          { |r| escalate(r) }
```

Allowed keys: `:complete`, `:interrupted`, `:success`, `:skipped`, `:failed`, `:ok`, `:ko`. Passing any other symbol raises `ArgumentError`. Missing block raises `ArgumentError`. Returns `self` for chaining.

`on(:failed, :skipped) { ... }` fires on either.

## Pattern matching

### Array form — `deconstruct`

```
[type, task, state, status, reason, metadata, cause, origin]
```

```ruby
case result
in ["Task",     _, "complete",    "success", *]            then success
in ["Workflow", _, "interrupted", "failed",  reason, *]    then fail(reason)
in [_, _, _, "skipped", reason, *]                         then skip(reason)
end
```

### Hash form — `deconstruct_keys`

Available keys:

```
:chain_root, :type, :task, :state, :status, :reason, :metadata,
:cause, :origin, :strict, :deprecated, :retries, :rolled_back, :duration
```

```ruby
case result
in { status: "failed", metadata: { retryable: true } }     then requeue(result)
in { state: "complete", task: ChargeCard }                 then confirm
in { rolled_back: true }                                   then audit_rollback
end
```

## Serialization

### `to_h`

Memoized. Always includes: `:chain_id`, `:chain_index`, `:chain_root`, `:type`, `:task`, `:id`, `:context`, `:state`, `:status`, `:reason`, `:metadata`, `:strict`, `:deprecated`, `:retried`, `:retries`, `:duration`, `:tags`.

When `failed?`, additionally includes: `:cause`, `:origin`, `:threw_failure`, `:caused_failure`, `:rolled_back`. Failure references render as `{ task: TaskClass, id: "uuid" }` — the live `Result` objects aren't walked to avoid cycles.

### `to_s`

Space-separated `key=value.inspect`. Failure references render as `<TaskClass uuid>`. Used as the default log line for every task execution.

## Chain

```ruby
result.chain            # CMDx::Chain
result.chain.id         # UUID v7
result.chain.size       # number of Results in this propagation
result.chain.map(&:task) # Classes, in insertion order
```

The root result is the **first** element (via `unshift`); non-root results are `push`ed in execution order. Frozen on teardown.

## Freezing

After Runtime's teardown:

- `task`, `errors`, and (when root) `context` and `chain` are frozen.
- `result` itself is immutable (everything is read-only).
- Mutations via `context.key = value` after teardown raise `FrozenError`.

Capture anything you need before teardown, or use `context.deep_dup` to get an unfrozen snapshot.
