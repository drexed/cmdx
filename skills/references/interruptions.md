# Interruptions Reference

Docs: [docs/interruptions/signals.md](../../docs/interruptions/signals.md), [docs/interruptions/faults.md](../../docs/interruptions/faults.md), [docs/interruptions/exceptions.md](../../docs/interruptions/exceptions.md).

## Signals

Four private methods on `Task` halt `work` by `throw`ing a `CMDx::Signal` caught by Runtime. Signatures:

| Method | Effect | Signature |
|--------|--------|-----------|
| `success!(reason = nil, **metadata)` | state: `complete`, status: `success` | reason + metadata hash |
| `skip!(reason = nil, **metadata)` | state: `interrupted`, status: `skipped` | reason + metadata hash |
| `fail!(reason = nil, **metadata)` | state: `interrupted`, status: `failed` | reason + metadata hash + signal backtrace |
| `throw!(other_result, **metadata)` | re-throws `other_result`'s failed signal | must receive a `Result`; no-op unless `other_result.failed?` |

All four raise `FrozenError` if called on a frozen task (i.e. after teardown). They only work inside `work`; calling them elsewhere bypasses the signal `catch`.

```ruby
def work
  success!("Imported #{n} rows", rows: n)
  skip!("Already processed", idempotency_key: key)
  fail!("Not found", code: "NOT_FOUND")
  throw!(InnerTask.execute(context))      # no-op if InnerTask succeeded
end
```

Anything after a halt is unreachable — signals `throw`, they don't raise.

## Errors (auto-fail)

Accumulate validation-style errors on `task.errors`; if any exist after `work`, Runtime throws `Signal.failed(errors.to_s)` automatically — no explicit `fail!` needed. Input resolution, output verification, and any manual `errors.add` during `work` all feed the same container.

```ruby
def work
  errors.add(:email, "invalid format") unless email.include?("@")
  errors.add(:age,   "must be positive") unless age.positive?
  # falls through; Runtime fails the task because errors isn't empty
end
```

Errors API:

| Method | Description |
|--------|-------------|
| `add(key, message)` / `[]=` | Adds; duplicate messages per key are dropped. |
| `[](key)` | Array of messages (frozen empty array when absent). |
| `added?(key, message)` | Boolean membership. |
| `key?(key)` / `for?(key)` | Key presence. |
| `keys` / `size` / `count` / `empty?` | Introspection. |
| `delete(key)` / `clear` | Mutation. |
| `to_h` / `to_hash` | `{ key => [messages] }`. |
| `full_messages` | `{ key => ["<key> <msg>"] }`. |
| `to_s` | `full_messages.values.flatten.join(". ")` — used as fail reason. |

Frozen on teardown.

## Faults

Failures raised from strict execution (`execute!`) are `CMDx::Fault`. There is **one** fault class — no `FailFault`/`SkipFault`. `execute!` does **not** raise on skip.

```ruby
begin
  ProcessPayment.execute!(...)
rescue CMDx::Fault => e
  e.message    # result.reason (or localized "cmdx.reasons.unspecified")
  e.result     # the originating (leaf) failed Result
  e.task       # the failing Task class
  e.context    # frozen Context
  e.chain      # the full CMDx::Chain
end
```

`Fault` delegates `task` / `context` / `chain` to `result`. Its backtrace is set from `result.backtrace` (captured by `fail!`) or `result.cause.backtrace_locations`, cleaned through `task.settings.backtrace_cleaner` if configured.

### Matchers

```ruby
rescue CMDx::Fault.for?(ProcessPayment, ChargeCard) => e
  # any fault where e.task <= ProcessPayment or <= ChargeCard
rescue CMDx::Fault.matches? { |f| f.result.metadata[:critical] } => e
  # custom predicate on the fault
```

`for?` raises `ArgumentError` if no tasks given. `matches?` raises `ArgumentError` without a block.

### `execute!` raise rules

When `result.failed?` and `strict: true`:

- If `result.cause` is a non-`Fault` `StandardError`, **re-raises the original exception** (preserves class + backtrace).
- Otherwise, raises `CMDx::Fault.new(result.caused_failure)` — the deepest leaf in the propagation chain.

Skipped results never raise. Successful results never raise.

## Propagation strategies

Pick per call-site:

| Strategy | Call form | Outer task's behavior when inner fails |
|----------|-----------|----------------------------------------|
| Swallow  | `InnerTask.execute(context)` | Returns Result; outer keeps going unless you check `result.failed?`. |
| Throw    | `throw!(InnerTask.execute(context))` | Echoes the failed signal — outer halts with the leaf as origin. Skips are a no-op. |
| Raise    | `InnerTask.execute!(context)` | Raises `CMDx::Fault` (or the original exception) inside `work`. Runtime's outer rescue converts it into an echoed signal anyway. |

Inside a workflow, the `Pipeline` uses `throw!` on a failed group result automatically, so the workflow's own result carries the leaf's `origin`/`caused_failure`/`threw_failure`.

## Exception hierarchy

Flat, rooted at `CMDx::Error` (aliased `CMDx::Exception`):

```
StandardError
└── CMDx::Error
    ├── CMDx::DefinitionError      # input reader name collides with existing method
    ├── CMDx::DeprecationError     # deprecation :error path was taken
    ├── CMDx::ImplementationError  # missing #work, or #work defined on a Workflow
    ├── CMDx::MiddlewareError      # middleware didn't yield
    └── CMDx::Fault                # raised by execute! on failed? results
```

Runtime's `rescue` chain inside `catch(Signal::TAG)`:

1. `Fault` → converted to `Signal.echoed(fault.result, cause: fault)` (propagates the leaf).
2. `CMDx::Error` (any other subclass) → **re-raised** past the signal catch; fails the whole execution outside of result machinery.
3. `StandardError` → converted to `Signal.failed("[Class] message", cause: e)`; the exception lives on `result.cause`.

Because `CMDx::Error` is re-raised, `DefinitionError` / `ImplementationError` / `MiddlewareError` / `DeprecationError` propagate out of `execute` unconverted — they indicate framework misuse, not runtime failure.
