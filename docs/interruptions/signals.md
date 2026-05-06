# Interruptions - Signals

Sometimes you already know how a task should end before you finish the method. CMDx gives you four friendly "stop here" helpers: `success!`, `skip!`, `fail!`, and `throw!`. Each one says what you mean, and you can attach a human-readable reason plus extra data for logs or APIs.

Under the hood they `throw` a `CMDx::Signal`. The runtime catches that around `work`, so execution jumps out right away — nothing below the halt line runs.

!!! note

    `success!` is the "happy stop" with a custom reason and metadata. For the full picture, see [Annotating a Successful Result](../outcomes/result.md#annotating-a-successful-result).

## Skipping

Use `skip!` when the task does not need to do anything useful right now. That is a deliberate choice, not a bug.

!!! warning "Heads up"

    A skip still counts as an OK outcome (`result.ok?` is true). `execute!` only raises on a real failure — it stays quiet on skips.

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

Use `fail!` when the task cannot honestly finish as a success. You stay in control: you chose to stop, you pick the message.

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

!!! note

    `result.reason` is whatever string you passed (or `nil`). The generic "unspecified" text only shows up on `Fault#message` when `execute!` raises and you never gave a reason.

## Metadata Enrichment

Want more than a string? Pass keyword arguments. They merge into `Task#metadata`, then ride along on the signal. If middleware already stuffed a request id into `task.metadata`, it still shows up — you do not have to copy it by hand.

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

Halt helpers always `throw`. They never "return" to the next line in `work`. The first one that runs wins; anything after it is dead code until the method ends.

```ruby
class ProcessOrder < CMDx::Task
  def work
    fail!("Out of stock") if out_of_stock?
    fail!("Insufficient funds") if insufficient_funds?
    # If both are true, only the first fail! runs.
  end
end
```

!!! warning "Where they work"

    These helpers only work inside `work` (or code `work` calls). If you try them from rollback, callbacks, or middleware you get `UncaughtThrowError`. On a frozen task after teardown you get `FrozenError`. Stay inside the story.

## State Transitions

Each halt maps to a simple combo of state, status, and how `ok?` / `ko?` read:

| Method | State | Status | Outcome |
|--------|-------|--------|---------|
| `success!` | `complete` | `success` | `ok? = true`, `ko? = false` |
| `skip!` | `interrupted` | `skipped` | `ok? = true`, `ko? = true` |
| `fail!` | `interrupted` | `failed` | `ok? = false`, `ko? = true` |
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

`execute` always hands you a `Result`, whether `work` ran to the end or stopped on a signal. `execute!` only raises when the outcome is a failure; skips and custom successes return normally. For the full contract see [Basics - Execution](../basics/execution.md). For what actually gets raised, see [Interruptions - Faults](faults.md).

## Rethrowing a Peer Failure

`throw!` is your "echo this other task's failure" button. If the other result is not failed, nothing happens and you keep going.

```ruby
class ReportMonthlyMetrics < CMDx::Task
  def work
    result = BuildReport.execute(context)
    throw!(result) # Copies the peer's state/status/reason; see `origin` for upstream.
                   # Metadata on *this* result is this task's metadata (plus any kwargs
                   # you pass to throw!), not a copy of the peer's hash.

    # Happy path continues here when result isn't failed
  end
end
```

The `Result` you get back keeps the upstream failure in `result.origin`, and `result.thrown_failure?` is true when you echoed a failure. More detail in [Result - Chain Analysis](../outcomes/result.md#chain-analysis).

!!! note

    `throw!` accepts a `Result` or a raw `CMDx::Signal`. If the input is not failed, it is a no-op. Handy when you want to forward a halt without unpacking it yourself.

## Best Practices

Specific reasons make everyone's life easier: they land on `result.reason`, in `Fault#message`, and in logs.

```ruby
# Best: specific reason + structured metadata
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Good: clear reason
skip!("Document processing paused for compliance review")

# Avoid: nil reason (Fault#message falls back to localized cmdx.reasons.unspecified)
skip!
fail!
```

## Manual Errors

You can also push errors onto `task.errors` as you go. If any are still there when `work` returns, the runtime turns that into a failed signal for you — no explicit `fail!` needed.

```ruby
class ProcessRenewal < CMDx::Task
  def work
    document = Document.find(context.document_id)
    errors.add(:document, "is not renewable") if document.nonrenewable?
    document.renew! if errors.empty?
  end
end
```

See [Outcomes - Errors](../outcomes/errors.md) for the full `errors` API.
