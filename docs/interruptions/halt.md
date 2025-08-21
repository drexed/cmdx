# Interruptions - Halt

Halting stops task execution with explicit intent signaling. Tasks provide two primary halt methods that control execution flow and result in different outcomes.

## Table of Contents

- [Skipping](#skipping)
- [Failing](#failing)
- [Metadata Enrichment](#metadata-enrichment)
- [State Transitions](#state-transitions)
- [Execution Behavior](#execution-behavior)
  - [Non-bang execution](#non-bang-execution)
  - [Bang execution](#bang-execution)
- [Best Practices](#best-practices)

## Skipping

`skip!` communicates that the task is to be intentionally bypassed. This represents a controlled, intentional interruption where the task determines that execution is not necessary or appropriate.

> [!IMPORTANT]
> Skipping is a no-op, not a failure or error and are considered successful outcomes.

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
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Warehouse closed"
```

## Failing

`fail!` communicates that the task encountered an impediment that prevents successful completion. This represents controlled failure where the task explicitly determines that execution cannot continue.

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
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Refund period has expired"
```

## Metadata Enrichment

Both halt methods accept metadata to provide additional context about the interruption. Metadata is stored as a hash and becomes available through the result object.

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

## State Transitions

Halt methods trigger specific state and status transitions:

| Method | State | Status | Outcome |
|--------|-------|--------|---------|
| `skip!` | `interrupted` | `skipped` | `good? = true`, `bad? = true` |
| `fail!` | `interrupted` | `failed` | `good? = false`, `bad? = true` |

```ruby
result = ProcessRenewal.execute(license_id: 567)

# State information
result.state        #=> "interrupted"
result.status       #=> "skipped" or "failed"
result.interrupted? #=> true
result.complete?    #=> false

# Outcome categorization
result.good?        #=> true for skipped, false for failed
result.bad?         #=> true for both skipped and failed
```

## Execution Behavior

Halt methods behave differently depending on the call method used:

### Non-bang execution

Returns result object without raising exceptions:

```ruby
result = ProcessRefund.execute(refund_id: 789)

case result.status
when "success"
  puts "Refund processed: $#{result.context.refund.amount}"
when "skipped"
  puts "Refund skipped: #{result.reason}"
when "failed"
  puts "Refund failed: #{result.reason}"
  handle_refund_error(result.metadata[:error_code])
end
```

### Bang execution

Raises exceptions for halt conditions based on `task_breakpoints` configuration:

```ruby
begin
  result = ProcessRefund.execute!(refund_id: 789)
  puts "Success: Refund processed"
rescue CMDx::SkipFault => e
  puts "Skipped: #{e.message}"
rescue CMDx::FailFault => e
  puts "Failed: #{e.message}"
  handle_refund_failure(e.result.metadata[:error_code])
end
```

## Best Practices

Always try to provide a `reason` when using halt methods. This provides clear context for debugging and creates meaningful exception messages.

```ruby
# Good: Clear, specific reason
skip!("Document processing paused for compliance review")
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Acceptable: Generic, non-specific reason
skip!("Paused")
fail!("Unsupported")

# Bad: Default, cannot determine reason
skip! #=> "no reason given"
fail! #=> "no reason given"
```

---

- **Prev:** [Basics - Chain](../basics/chain.md)
- **Next:** [Interruptions - Faults](faults.md)
