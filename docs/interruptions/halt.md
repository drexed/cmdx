# Interruptions - Halt

Halting stops execution of a task with explicit intent signaling. Tasks provide two primary halt methods that control execution flow and result in different outcomes, each serving specific use cases in business logic.

## Table of Contents

- [TLDR](#tldr)
- [Skip (`skip!`)](#skip-skip)
- [Fail (`fail!`)](#fail-fail)
- [Metadata Enrichment](#metadata-enrichment)
- [State Transitions](#state-transitions)
- [Exception Behavior](#exception-behavior)
- [Error Handling](#error-handling)
- [The Reason Key](#the-reason-key)

## TLDR

```ruby
# Skip when task shouldn't execute (not an error)
skip!(Order already processed")

# Fail when task encounters error condition
fail!(Insufficient funds", error_code: "PAYMENT_DECLINED")

# With structured metadata
skip!(
  User inactive",
  user_id: 123,
  last_active: "2023-01-01"
)

# Exception behavior with call vs call!
result = Task.call(params)    # Returns result object
Task.call!(params)            # Raises CMDx::SkipFault/Failed on halt
```

## Skip (`skip!`)

> [!NOTE]
> Use `skip!` when a task cannot or should not execute under current conditions, but this is not an error. Skipped tasks are considered successful outcomes.

The `skip!` method indicates that a task did not meet the criteria to continue execution. This represents a controlled, intentional interruption where the task determines that execution is not necessary or appropriate.

### Basic Usage

```ruby
class ProcessOrder < CMDx::Task
  required :order_id, type: :integer

  def call
    context.order = Order.find(order_id)

    # Skip if order already processed
    skip!(Order already processed") if context.order.processed?

    # Skip if prerequisites not met
    skip!(Payment method required") unless context.order.payment_method

    # Continue with business logic
    context.order.process!
  end
end
```

### Common Skip Scenarios

| Scenario | Example |
|----------|---------|
| **Already processed** | `skip!(User already verified")` |
| **Prerequisites missing** | `skip!(Required documents not uploaded")` |
| **Business rules** | `skip!(Outside business hours")` |
| **State conditions** | `skip!(Account suspended")` |

## Fail (`fail!`)

> [!IMPORTANT]
> Use `fail!` when a task encounters an error that prevents successful completion. Failed tasks represent error conditions that need to be handled or corrected.

The `fail!` method indicates that a task encountered an error condition that prevents successful completion. This represents controlled failure where the task explicitly determines that execution cannot continue.

### Basic Usage

```ruby
class ProcessPayment < CMDx::Task
  required :payment_id, type: :integer

  def call
    context.payment = Payment.find(payment_id)

    # Fail on validation errors
    fail!(Payment amount must be positive") unless context.payment.amount > 0

    # Fail on business rule violations
    fail!(Insufficient funds", code: "INSUFFICIENT_FUNDS") unless sufficient_funds?

    # Continue with processing
    charge_payment
  end

  private

  def sufficient_funds?
    context.payment.account.balance >= context.payment.amount
  end
end
```

### Common Fail Scenarios

| Scenario | Example |
|----------|---------|
| **Validation errors** | `fail!(Invalid email format")` |
| **Business rule violations** | `fail!(Credit limit exceeded")` |
| **External service errors** | `fail!(Payment gateway unavailable")` |
| **Data integrity issues** | `fail!(Duplicate transaction detected")` |

## Metadata Enrichment

Both halt methods accept metadata to provide context about the interruption. Metadata is stored as a hash and becomes available through the result object.

### Structured Metadata

```ruby
class ProcessSubscription < CMDx::Task
  required :user_id, type: :integer

  def call
    context.user = User.find(user_id)

    if context.user.subscription_expired?
      skip!(
        Subscription expired",
        user_id: context.user.id,
        expired_at: context.user.subscription_expires_at,
        plan_type: context.user.subscription_plan,
        grace_period_ends: context.user.subscription_expires_at + 7.days
      )
    end

    unless context.user.payment_method_valid?
      fail!(
        Invalid payment method",
        user_id: context.user.id,
        payment_method_id: context.user.payment_method&.id,
        error_code: "PAYMENT_METHOD_INVALID",
        retry_after: Time.current + 1.hour
      )
    end

    process_subscription
  end
end
```

### Accessing Metadata

```ruby
result = ProcessSubscriptionTask.call(user_id: 123)

# Check result status
result.skipped?                         #=> true
result.failed?                          #=> false

# Access metadata
result.metadata[:reason]                #=> "Subscription expired"
result.metadata[:user_id]               #=> 123
result.metadata[:expired_at]            #=> 2023-01-01 10:00:00 UTC
result.metadata[:grace_period_ends]     #=> 2023-01-08 10:00:00 UTC
```

## State Transitions

Halt methods trigger specific state and status transitions:

| Method | State Transition | Status | Outcome |
|--------|------------------|--------|---------|
| `skip!` | `executing` → `interrupted` | `skipped` | `good? = true`, `bad? = true` |
| `fail!` | `executing` → `interrupted` | `failed` | `good? = false`, `bad? = true` |

```ruby
result = ProcessSubscriptionTask.call(user_id: 123)

# State information
result.state        #=> "interrupted"
result.status       #=> "skipped" or "failed"
result.interrupted? #=> true
result.complete?    #=> false

# Outcome categorization
result.good?        #=> true for skipped, false for failed
result.bad?         #=> true for both skipped and failed
```

## Exception Behavior

Halt methods behave differently depending on the call method used:

### With `call` (Non-bang)

Returns a result object without raising exceptions:

```ruby
result = ProcessPaymentTask.call(payment_id: 123)

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

### With `call!` (Bang)

> [!WARNING]
> The `call!` method raises exceptions for halt conditions based on the `task_halt` configuration. Handle these exceptions appropriately in your application flow.

```ruby
begin
  result = ProcessPaymentTask.call!(payment_id: 123)
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

## Error Handling

### Invalid Metadata

```ruby
class ProcessOrder < CMDx::Task
  def call
    # This works - metadata accepts any hash
    skip!(Valid skip", order_id: 123, custom_data: {nested: true})

    # This also works - no metadata required
    fail!
  end
end
```

## The Reason Key

> [!TIP]
> Always include a `:reason` key in metadata when using halt methods. This provides clear context for debugging and creates meaningful exception messages.

The `:reason` key in metadata has special significance:

- Used as the exception message when faults are raised
- Provides human-readable explanation of the halt
- Strongly recommended for all halt calls

```ruby
# Good: Clear, specific reason
skip!(User account suspended until manual review")
fail!(Credit card declined by issuer", code: "CARD_DECLINED")

# Acceptable: Other metadata without reason
skip!(status: "redundant", processed_at: Time.current)

# Fallback: Default message if no reason provided
skip! # Exception message: "no reason given"
fail! # Exception message: "no reason given"
```

### Reason Best Practices

| Practice | Example |
|----------|---------|
| **Be specific** | `"Credit card expired on 2023-12-31"` vs `"Payment error"` |
| **Include context** | `"Inventory insufficient: need 5, have 2"` |
| **Use actionable language** | `"Email verification required before login"` |
| **Avoid technical jargon** | `"Payment declined"` vs `"Gateway returned 402"` |

---

- **Prev:** [Basics - Chain](../basics/chain.md)
- **Next:** [Interruptions - Faults](faults.md)
