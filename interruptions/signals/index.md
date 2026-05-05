# Interruptions - Signals

Halt `work` intentionally with `success!`, `skip!`, `fail!`, or `throw!`. Each signals a clear intent and can carry a reason and metadata.

Internally these methods `throw` a `CMDx::Signal` that Runtime catches around `work`, breaking out of the current call stack the moment they fire — nothing after them runs.

Note

`success!` is the third halt method; it produces a `complete`/`success` result with a custom reason and metadata. See [Annotating a Successful Result](https://drexed.github.io/cmdx/outcomes/result/#annotating-a-successful-result).

## Skipping

Use `skip!` when the task doesn't need to run. It's a controlled no-op, not an error.

Important

Skipped tasks are considered "ok" outcomes (`result.ok? #=> true`). `execute!` does **not** raise on a skip — only on a failure.

```ruby
class ProcessInventory < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["DISABLED_TASKS"]).include?(self.class.name)

    # With a reason
    skip!("Warehouse closed") unless Time.now.hour.between?(8, 18)

    inventory = Inventory.find(context.inventory_id)

    if inventory.already_counted?
      skip!("Inventory already counted today")
    else
      inventory.count!
    end
  end
end

result = ProcessInventory.execute(inventory_id: 456)

# Executed
result.status #=> "skipped"

# Without a reason
result.reason #=> nil

# With a reason
result.reason #=> "Warehouse closed"
```

## Failing

Use `fail!` when the task can't complete successfully. It signals controlled, intentional failure:

```ruby
class ProcessRefund < CMDx::Task
  def work
    # Without a reason
    fail! if Array(ENV["DISABLED_TASKS"]).include?(self.class.name)

    refund = Refund.find(context.refund_id)

    # With a reason
    if refund.expired?
      fail!("Refund period has expired")
    elsif !refund.amount.positive?
      fail!("Refund amount must be positive")
    else
      refund.process!
    end
  end
end

result = ProcessRefund.execute(refund_id: 789)

# Executed
result.status #=> "failed"

# Without a reason
result.reason #=> nil

# With a reason
result.reason #=> "Refund period has expired"
```

Note

`result.reason` is exactly what you passed (or `nil`). The localized `cmdx.reasons.unspecified` fallback only appears on `Fault#message` when `execute!` raises with no reason.

## Metadata Enrichment

Enrich halt calls with metadata for better debugging and error handling. Keyword args passed to `success!` / `skip!` / `fail!` / `throw!` are merged into `Task#metadata` first, then the resulting hash is attached to the thrown `Signal` — so middlewares that pre-populated `task.metadata` (e.g. a request id) show up on the same result without the caller having to forward them.

```ruby
class ProcessRenewal < CMDx::Task
  def work
    license = License.find(context.license_id)

    if license.already_renewed?
      # Without metadata
      skip!("License already renewed")
    end

    unless license.renewal_eligible?
      # With metadata
      fail!(
        "License not eligible for renewal",
        error_code: "LICENSE.NOT_ELIGIBLE",
        retry_after: Time.current + 30.days
      )
    end

    process_renewal
  end
end

result = ProcessRenewal.execute(license_id: 567)

# Without metadata
result.metadata #=> {}

# With metadata
result.metadata #=> {
                #     error_code: "LICENSE.NOT_ELIGIBLE",
                #     retry_after: <Time 30 days from now>
                #   }
```

## Short-Circuit Behavior

Halt methods always `throw` — they never return. The first one to fire ends `work` immediately, so any subsequent halt calls are unreachable:

```ruby
class ProcessOrder < CMDx::Task
  def work
    fail!("Out of stock") if out_of_stock?
    fail!("Insufficient funds") if insufficient_funds?
    # If both conditions are true, only the first fail! ever runs.
  end
end
```

Important

Halt methods only work inside `work` (and anything it calls). Throwing from rollback, callbacks, or middlewares raises `UncaughtThrowError`; on a frozen task (post-teardown) they raise `FrozenError`.

## State Transitions

Halt methods trigger specific state and status transitions:

| Method           | State         | Status                      | Outcome                     |
| ---------------- | ------------- | --------------------------- | --------------------------- |
| `success!`       | `complete`    | `success`                   | `ok? = true`, `ko? = false` |
| `skip!`          | `interrupted` | `skipped`                   | `ok? = true`, `ko? = true`  |
| `fail!`          | `interrupted` | `failed`                    | `ok? = false`, `ko? = true` |
| `throw!(failed)` | `interrupted` | `failed` (mirrors upstream) | `ok? = false`, `ko? = true` |

```ruby
result = ProcessRenewal.execute(license_id: 567)

# State information
result.state        #=> "interrupted"
result.status       #=> "skipped" or "failed"
result.interrupted? #=> true
result.complete?    #=> false

# Outcome categorization
result.ok?          #=> true for skipped, false for failed
result.ko?          #=> true for both skipped and failed
```

## Execution Behavior

`execute` always returns a `Result`, regardless of whether `work` finished normally or halted via a signal. `execute!` only raises on `failed?` — `skip!` and `success!` return normally. See [Basics - Execution](https://drexed.github.io/cmdx/basics/execution/index.md) for the full entry-point contract and [Interruptions - Faults](https://drexed.github.io/cmdx/interruptions/faults/index.md) for the rescued exception hierarchy.

## Rethrowing a Peer Failure

Use `throw!` to halt the current task by echoing another task's failed result. It's a no-op when the other result isn't `failed?`:

```ruby
class ReportMonthlyMetrics < CMDx::Task
  def work
    result = BuildReport.execute(context)
    throw!(result) # echoes the peer's state/status/reason; the upstream
                   # result is exposed via `origin`. Metadata on this task's
                   # result is this task's `metadata` (merged with any kwargs
                   # passed to throw!), not a copy of the peer's metadata.

    # ...happy path continues here when result isn't failed
  end
end
```

The resulting `Result` carries the upstream failure in `result.origin`; `result.thrown_failure?` is `true`. See [Result - Chain Analysis](https://drexed.github.io/cmdx/outcomes/result/#chain-analysis).

Note

`throw!` accepts a `Result` or a raw `CMDx::Signal`. Non-failed inputs are a no-op (caller continues past the `throw!`). Use it to forward another task's halt state without unwrapping.

## Best Practices

Prefer specific reasons — they become `result.reason`, `Fault#message`, and end up in logs and telemetry:

```ruby
# Best: Specific reason + structured metadata
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Good: Clear reason
skip!("Document processing paused for compliance review")

# Avoid: nil reason (Fault#message falls back to the localized cmdx.reasons.unspecified)
skip!
fail!
```

## Manual Errors

Accumulate structured errors on `task.errors` during `work`; if any are present when `work` returns, Runtime throws a failed signal whose reason is the joined messages — no explicit `fail!` required.

```ruby
class ProcessRenewal < CMDx::Task
  def work
    document = Document.find(context.document_id)
    errors.add(:document, "is not renewable") if document.nonrenewable?
    document.renew! if errors.empty?
  end
end
```

See [Outcomes - Errors](https://drexed.github.io/cmdx/outcomes/errors/index.md) for the full `errors` API.
