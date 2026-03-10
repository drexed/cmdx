# Interruptions - Halt

Stop task execution intentionally using `skip!` or `fail!`. Both methods signal clear intent about why execution stopped.

## Skipping

Use `skip!` when the task doesn't need to run. It's a no-op, not an error.

Important

Skipped tasks are considered "good" outcomes—they succeeded by doing nothing.

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
result.reason #=> "Unspecified"

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
result.reason #=> "Unspecified"

# With a reason
result.reason #=> "Refund period has expired"
```

## Metadata Enrichment

Enrich halt calls with metadata for better debugging and error handling:

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

## Idempotency

Halt methods are safe to call when the result is already in the target status:

```ruby
class ProcessOrder < CMDx::Task
  def work
    fail!("Out of stock") if out_of_stock?
    fail!("Insufficient funds") if insufficient_funds?
    # Second fail! is a no-op if already failed above
  end
end
```

Important

`skip!` and `fail!` are no-ops when the result is already in the matching status. However, calling `skip!` after `fail!` (or vice versa) raises a `RuntimeError` — status transitions are unidirectional.

## State Transitions

Halt methods trigger specific state and status transitions:

| Method  | State         | Status    | Outcome                        |
| ------- | ------------- | --------- | ------------------------------ |
| `skip!` | `interrupted` | `skipped` | `good? = true`, `bad? = true`  |
| `fail!` | `interrupted` | `failed`  | `good? = false`, `bad? = true` |

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

Always provide a reason for better debugging and clearer exception messages:

```ruby
# Good: Clear, specific reason
skip!("Document processing paused for compliance review")
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Acceptable: Generic, non-specific reason
skip!("Paused")
fail!("Unsupported")

# Bad: Default, cannot determine reason
skip! #=> "Unspecified"
fail! #=> "Unspecified"
```

## Manual Errors

For rare cases, manually add errors before halting.

Important

Manual errors don't stop execution—you still need to call `fail!` or `skip!`.

### Errors API

The `errors` object provides methods for querying and formatting error messages:

```ruby
errors.add(:email, "is invalid")
errors.add(:email, "is required")
errors.add(:name, "is too short")

errors.any?              #=> true
errors.empty?            #=> false
errors.size              #=> 2 (number of attributes with errors)
errors.for?(:email)      #=> true
errors.for?(:phone)      #=> false

errors.to_h              #=> { email: ["is invalid", "is required"], name: ["is too short"] }
errors.full_messages     #=> { email: ["email is invalid", "email is required"], name: ["name is too short"] }
errors.to_s              #=> "email is invalid. email is required. name is too short"
```

### Usage

```ruby
class ProcessRenewal < CMDx::Task
  def work
    if document.nonrenewable?
      errors.add(:document, "not renewable")
      fail!("document could not be renewed")
    else
      document.renew!
    end
  end
end
```
