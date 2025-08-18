# Interruptions - Halt

Halting stops execution of a task with explicit intent signaling. Tasks provide two primary halt methods that control execution flow and result in different outcomes, each serving specific use cases in business logic.

## Table of Contents

- [Skipping](#skipping)
- [Failing](#failing)
- [Metadata Enrichment](#metadata-enrichment)
- [State Transitions](#state-transitions)
- [Execution Behavior](#execution-behavior)
- [Halt Reasons](#halt-reasons)

## Skipping

The `skip!` method indicates that a task did not meet the criteria to continue execution. This represents a controlled, intentional interruption where the task determines that execution is not necessary or appropriate.

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["PHASED_OUT_TASKS"]).include?(self.class.name)

    # With a reason
    skip!("Outside of business hours") unless Time.now.hour.between?(9, 17)

    order = Order.find(context.order_id)

    if order.processed?
      skip!("Order already processed")
    else
      order.process!
    end
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Executed
result.status #=> "skipped"

# Without a reason
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Outside of business hours"
```

> [!NOTE]
> Skipping is not an error or failure. Skipped tasks are considered successful outcomes.

## Failing

The `fail!` method indicates that a task encountered an error condition that prevents successful completion. This represents controlled failure where the task explicitly determines that execution cannot continue.

```ruby
class ProcessPayment < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["PHASED_OUT_TASKS"]).include?(self.class.name)

    payment = Payment.find(context.payment_id)

    # With a reason
    if payment.unsupported_type?
      fail!("Unsupported payment type")
    elsif !payment.amount.positive?
      fail!("Payment amount must be positive")
    else
      payment.charge!
    end
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Executed
result.status #=> "failed"

# Without a reason
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Unsupported payment type"
```

## Metadata Enrichment

Both halt methods accept metadata to provide context about the interruption. Metadata is stored as a hash and becomes available through the result object.

```ruby
class ProcessSubscription < CMDx::Task
  def work
    user = User.find(context.user_id)

    if user.subscription_expired?
      # Without metadata
      skip!("Subscription expired")
    end

    unless user.payment_method_valid?
      # With metadata
      fail!(
        "Invalid payment method",
        error_code: "PAYMENT_METHOD.INVALID",
        retry_after: Time.current + 1.hour
      )
    end

    process_subscription
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Without metadata
result.metadata #=> {}

# With metadata
result.metadata #=> {
                #     error_code: "PAYMENT_METHOD.INVALID",
                #     retry_after: #<Time 1 hour from now>
                #   }
```

## State Transitions

Halt methods trigger specific state and status transitions:

| Method | State Transition | Status | Outcome |
|--------|------------------|--------|---------|
| `skip!` | `executing` → `interrupted` | `skipped` | `good? = true`, `bad? = true` |
| `fail!` | `executing` → `interrupted` | `failed` | `good? = false`, `bad? = true` |

```ruby
result = ProcessSubscription.execute(user_id: 123)

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

### With `execute` (Non-bang)

Returns a result object without raising exceptions:

```ruby
result = ProcessPayment.execute(payment_id: 123)

case result.status
when "success"
  puts "Payment processed: $#{result.context.payment.amount}"
when "skipped"
  puts "Payment skipped: #{result.metadata[:reason]}"
when "failed"
  puts "Payment failed: #{result.metadata[:reason]}"
  handle_payment_error(result.metadata[:code])
end
```

### With `execute!` (Bang)

The `execute!` method raises exceptions for halt conditions based on the `task_breakpoints` configuration.
Handle these exceptions appropriately in your application flow.

```ruby
begin
  result = ProcessPayment.execute!(payment_id: 123)
  puts "Success: Payment processed for $#{result.context.payment.amount}"
rescue CMDx::SkipFault => e
  puts "Skipped: #{e.message}"
  log_skip_event(e.context.payment_id, e.result.metadata)
rescue CMDx::FailFault => e
  puts "Failed: #{e.message}"
  handle_payment_failure(e.result.metadata[:code])
  notify_payment_team(e.context.payment_id)
end
```

## Halt Reasons

Always provide a `reason` when using halt methods. This provides clear context for debugging and creates meaningful exception messages.

```ruby
# Good: Clear, specific reason
skip!("User account suspended until manual review")
fail!("Credit card declined by issuer", code: "CARD_DECLINED")

# Acceptable: Generic, non-specific reason
skip!("Suspended")
fail!("Declined")

# Bad: Default, cannot determine reason
skip! #=> "no reason given"
fail! #=> "no reason given"
```

Best Practices:

| Practice | Example |
|----------|---------|
| **Be specific** | `"Credit card expired on 2023-12-31"` vs `"Payment error"` |
| **Include context** | `"Inventory insufficient: need 5, have 2"` |
| **Use actionable language** | `"Email verification required before login"` |
| **Avoid technical jargon** | `"Payment declined"` vs `"Gateway returned 402"` |

---

- **Prev:** [Basics - Chain](../basics/chain.md)
- **Next:** [Interruptions - Faults](faults.md)
