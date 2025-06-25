# Interruptions - Halt

Halting stops execution of a task with explicit intent signaling. Tasks provide
two primary halt methods that control execution flow and result in different
outcomes, each serving specific use cases in business logic.

## Table of Contents

- [Skip (`skip!`)](#skip-skip)
- [Fail (`fail!`)](#fail-fail)
- [Metadata Enrichment](#metadata-enrichment)
- [State Transitions](#state-transitions)
- [Exception Behavior](#exception-behavior)
- [The Reason Key](#the-reason-key)

## Skip (`skip!`)

The `skip!` method indicates that a task did not meet the criteria to continue
execution. This represents a controlled, intentional interruption where the
task determines that execution is not necessary or appropriate under current
conditions.

### Basic Usage

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    context.order = Order.find(context.order_id)

    # Skip if order is already processed
    skip!("Order already processed") if context.order.processed?

    # Skip if prerequisites aren't met
    skip!("Payment method not configured") unless context.order.payment_method

    # Continue with business logic
    context.order.process!
  end

end
```

### Common Skip Scenarios

```ruby
class SendUserNotificationTask < CMDx::Task
  required :user_id, type: :integer
  optional :force, type: :boolean, default: false

  def call
    context.user = User.find(user_id)

    # Skip based on user preferences
    unless force || context.user.notifications_enabled?
      skip!("User has notifications disabled")
    end

    # Skip if already notified recently
    if context.user.last_notification_sent > 1.hour.ago
      skip!("Notification already sent recently")
    end

    NotificationService.send(context.user)
  end
end
```

> [!NOTE]
> Use `skip!` when a task cannot or should not execute under current conditions, but this is not an error. Skipped tasks are considered successful outcomes.

## Fail (`fail!`)

The `fail!` method indicates that a task encountered an error condition that
prevents successful completion. This represents controlled failure where the
task explicitly determines that execution cannot continue successfully.

### Basic Usage

```ruby
class ProcessOrderPaymentTask < CMDx::Task

  def call
    context.payment = Payment.find(context.payment_id)

    # Fail on validation errors
    fail!("Payment amount must be positive") unless context.payment.amount > 0

    # Fail on business rule violations
    fail!("Insufficient funds") unless sufficient_funds?

    # Continue with processing
    process_payment
  end

end
```

### Detailed Failure Handling

```ruby
class CreateUserAccountTask < CMDx::Task
  required :email, type: :string
  required :password, type: :string

  def call
    # Fail with detailed error information
    if User.exists?(email: email)
      fail!(
        "Email already exists",
        code: "EMAIL_EXISTS",
        field: "email",
        suggested_action: "Use different email or login instead"
      )
    end

    # Fail on validation errors
    unless valid_password_format?
      fail!(
        "Password must be at least 8 characters with special characters",
        code: "INVALID_PASSWORD",
        requirements: ["8+ characters", "special characters", "numbers"]
      )
    end

    context.user = User.create!(email: email, password: password)
  end
end
```

> [!IMPORTANT]
> Use `fail!` when a task encounters an error that prevents successful completion. Failed tasks represent error conditions that need to be handled or corrected.

## Metadata Enrichment

Both halt methods accept metadata to provide context about the interruption.
Metadata is stored as a hash and becomes available through the result object.

### Structured Metadata

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    context.order = Order.find(context.order_id)

    if context.order.status == "cancelled"
      skip!(
        reason: "Order was cancelled",
        order_id: context.order.id,
        cancelled_at: context.order.cancelled_at,
        reason_code: context.order.cancellation_reason
      )
    end

    unless inventory_available?
      fail!(
        reason: "Insufficient inventory",
        required_quantity: context.order.quantity,
        available_quantity: current_inventory,
        restock_date: estimated_restock_date,
        error_code: "INVENTORY_DEPLETED"
      )
    end

    process_order
  end

end
```

### Accessing Metadata

```ruby
result = ProcessUserOrderTask.call(order_id: 123)

# Check result status
result.skipped?                #=> true
result.failed?                 #=> false

# Access metadata
result.metadata[:reason]       #=> "Order was cancelled"
result.metadata[:order_id]     #=> 123
result.metadata[:cancelled_at] #=> 2023-01-01 10:00:00 UTC
result.metadata[:reason_code]  #=> "customer_request"
```

## State Transitions

Halt methods trigger specific state and status transitions:

### Skip Transitions
- **State**: `initialized` → `executing` → `interrupted`
- **Status**: `success` → `skipped`
- **Result**: `good? = true`, `bad? = true`

### Fail Transitions
- **State**: `initialized` → `executing` → `interrupted`
- **Status**: `success` → `failed`
- **Result**: `good? = false`, `bad? = true`

```ruby
result = ProcessUserOrderTask.call(order_id: 123)

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
result = ProcessUserOrderTask.call(order_id: 123)

case result.status
when "success"
  puts "Order processed successfully"
when "skipped"
  puts "Order skipped: #{result.metadata[:reason]}"
when "failed"
  puts "Order failed: #{result.metadata[:reason]}"
end
```

### With `call!` (Bang)
Raises fault exceptions based on `task_halt` configuration:

```ruby
begin
  result = ProcessUserOrderTask.call!(order_id: 123)
  puts "Success: #{result.context.order.id}"
rescue CMDx::Skipped => e
  puts "Skipped: #{e.message}"
  puts "Order ID: #{e.context.order_id}"
rescue CMDx::Failed => e
  puts "Failed: #{e.message}"
  puts "Error code: #{e.result.metadata[:error_code]}"
end
```

> [!WARNING]
> The `call!` method raises exceptions for halt conditions based on the `task_halt` configuration. The `call` method always returns result objects without raising exceptions.

## The Reason Key

The `:reason` key in metadata has special significance:

- Used as the exception message when faults are raised
- Provides human-readable explanation of the halt
- Strongly recommended for all halt calls

```ruby
# Good: Provides clear reason
skip!(reason: "User already has an active session")
fail!(reason: "Credit card expired", code: "EXPIRED_CARD")

# Acceptable: Other metadata without reason
skip!(status: "redundant", timestamp: Time.current)

# Fallback: Default message if no reason provided
skip! # Exception message: "no reason given"
```

> [!TIP]
> Always try to include a `:reason` key in metadata when using halt methods. This provides clear context for debugging and creates meaningful exception messages when using `call!`.

---

- **Prev:** [Basics - Run](https://github.com/drexed/cmdx/blob/main/docs/basics/run.md)
- **Next:** [Interruptions - Faults](https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md)
