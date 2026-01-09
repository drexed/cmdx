---
date: 2026-01-14
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-interruptions
---

# Mastering CMDx Interruptions: Controlling Flow When Things Go Sideways

Business logic isn't always a straight line. Orders get cancelled. Users don't have permissions. External APIs timeout. What separates robust code from fragile code is how gracefully you handle these interruptions.

CMDx gives you three tools for this: halt methods (`skip!` and `fail!`), exception handling, and faults. Together, they form a complete system for controlling execution flow—whether you're stopping intentionally, handling errors, or propagating failures across tasks.

<!-- more -->

## The Basics: Stopping Execution on Purpose

Let's start simple. You're building a task and something happens that means you shouldn't continue. CMDx gives you two explicit methods: `skip!` and `fail!`.

### Skipping: When There's Nothing to Do

Use `skip!` when the task legitimately shouldn't run. It's not an error—it's a no-op:

```ruby
class ProcessRefund < CMDx::Task
  def work
    refund = Refund.find(context.refund_id)

    if refund.already_processed?
      skip!("Refund was already processed on #{refund.processed_at}")
    end

    refund.process!
    context.refund = refund
  end
end
```

The key insight: **skipped tasks are considered successful outcomes**. The task succeeded by recognizing there was nothing to do.

```ruby
result = ProcessRefund.execute(refund_id: 456)

result.status   #=> "skipped"
result.reason   #=> "Refund was already processed on 2025-01-08"
result.good?    #=> true  # Not a failure!
result.bad?     #=> true  # But not success either
```

I use `skip!` constantly. Feature flags, already-processed checks, business hours validation—anywhere that "do nothing" is the correct outcome.

### Failing: When Something Goes Wrong

Use `fail!` when the task cannot complete. This is intentional, controlled failure:

```ruby
class ChargeSubscription < CMDx::Task
  def work
    subscription = Subscription.find(context.subscription_id)

    if subscription.cancelled?
      fail!("Cannot charge cancelled subscription")
    elsif subscription.payment_method.expired?
      fail!("Payment method has expired", code: :payment_expired)
    end

    charge = PaymentGateway.charge(subscription)
    context.charge = charge
  end
end
```

Unlike `skip!`, failed tasks are bad outcomes:

```ruby
result = ChargeSubscription.execute(subscription_id: 789)

result.status #=> "failed"
result.reason #=> "Payment method has expired"
result.good?  #=> false
result.bad?   #=> true
```

### Adding Context with Metadata

Both `skip!` and `fail!` accept metadata for richer debugging:

```ruby
class ProcessLicense < CMDx::Task
  def work
    license = License.find(context.license_key)

    unless license.renewable?
      fail!(
        "License not eligible for renewal",
        error_code: "LICENSE.NOT_RENEWABLE",
        expires_at: license.expires_at,
        retry_after: license.next_renewal_window
      )
    end

    license.renew!
  end
end

result = ProcessLicense.execute(license_key: "ABC-123")

result.metadata[:error_code]   #=> "LICENSE.NOT_RENEWABLE"
result.metadata[:retry_after]  #=> 2025-02-01 00:00:00 UTC
```

This metadata shows up in logs and is available in exception handlers. I always include error codes for API responses and retry hints for transient failures.

## Exception Handling: When the Unexpected Happens

`skip!` and `fail!` are for expected problems. But what about actual exceptions—database timeouts, network failures, nil pointer errors?

CMDx handles these differently depending on which execution method you use.

### Non-bang Execution: Capture Everything

With `execute`, exceptions become failed results:

```ruby
class FetchExternalData < CMDx::Task
  def work
    response = HTTP.get("https://api.example.com/data")
    context.data = JSON.parse(response.body)
  end
end

result = FetchExternalData.execute
result.failed?  #=> true
result.reason   #=> "[HTTP::TimeoutError] Connection timed out after 30s"
result.cause    #=> <HTTP::TimeoutError: Connection timed out after 30s>
```

Your calling code doesn't need a `rescue` block. The result tells you what happened, and the original exception is preserved in `cause` for debugging.

This is my default approach. One consistent pattern, no try/catch ceremony, and the exception is still available if I need to inspect it.

### Bang Execution: Let Exceptions Fly

With `execute!`, exceptions propagate naturally:

```ruby
begin
  FetchExternalData.execute!
rescue HTTP::TimeoutError => e
  # Handle network failure
  fallback_to_cache
rescue JSON::ParserError => e
  # Handle malformed response
  report_api_degradation
end
```

Use `execute!` when you want standard Ruby error handling or when failures should halt a larger process.

### Sending Exceptions to APM Tools

When using `execute` (non-bang), exceptions get captured into results—but you might still want to send them to Sentry, Datadog, or your APM of choice. Configure an exception handler:

```ruby
class ReportingTask < CMDx::Task
  settings exception_handler: ->(task, exception) {
    Sentry.capture_exception(exception, extra: {
      task_class: task.class.name,
      task_id: task.id,
      context: task.context.to_h
    })
  }

  def work
    # If this raises, exception goes to Sentry AND becomes a failed result
    risky_operation!
  end
end
```

The exception handler fires before the result is finalized, so you get notification while still returning a clean result object.

## Faults: Structured Exceptions for Halts

When you use `execute!` and a task calls `skip!` or `fail!`, CMDx raises a *fault*—a special exception that carries rich execution context.

```ruby
begin
  ProcessPayment.execute!(order_id: 123)
rescue CMDx::SkipFault => e
  # Task called skip!
  puts "Skipped: #{e.message}"
rescue CMDx::FailFault => e
  # Task called fail!
  puts "Failed: #{e.message}"
  puts "Error code: #{e.result.metadata[:error_code]}"
rescue CMDx::Fault => e
  # Catch-all for any halt
  puts "Interrupted: #{e.message}"
end
```

### Accessing Fault Data

Faults expose everything about the execution:

```ruby
begin
  ActivateLicense.execute!(license_key: key)
rescue CMDx::Fault => e
  # Result information
  e.result.state       #=> "interrupted"
  e.result.status      #=> "failed"
  e.result.reason      #=> "License already activated"
  e.result.metadata    #=> { error_code: "ALREADY_ACTIVE" }

  # Task information
  e.task.class.name    #=> "ActivateLicense"
  e.task.id            #=> "abc123..."

  # Context data
  e.context.license_key #=> "ABC-123-DEF"

  # Chain information (if part of a larger flow)
  e.chain.id           #=> "def456..."
  e.chain.size         #=> 3
end
```

This is invaluable for error reporting. Instead of just "something failed," you get the full picture: what task, what data, what chain of execution.

### Task-Specific Fault Matching

Sometimes you only want to catch faults from specific tasks. Use `for?`:

```ruby
begin
  OrderWorkflow.execute!(order_data: data)
rescue CMDx::FailFault.for?(PaymentProcessor, FraudCheck) => e
  # Only catches failures from these specific tasks
  handle_payment_failure(e)
rescue CMDx::SkipFault.for?(InventoryCheck) => e
  # Only catches skips from InventoryCheck
  notify_warehouse(e.context.order_id)
rescue CMDx::Fault => e
  # Everything else
  generic_error_handler(e)
end
```

This is powerful for workflows where different subtasks need different handling.

### Custom Matching Logic

For complex matching, use `matches?` with a block:

```ruby
begin
  BatchProcessor.execute!(items: large_batch)
rescue CMDx::Fault.matches? { |f| f.context.items.size > 1000 } => e
  # Large batch failures get special handling
  split_and_retry(e.context.items)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:retryable] } => e
  # Retryable failures
  schedule_retry(e)
rescue CMDx::Fault => e
  # Non-retryable failures
  abandon_batch(e)
end
```

## Propagating Failures with `throw!`

Real workflows have nested tasks. When a subtask fails, you often want to propagate that failure up—preserving all the context about what went wrong.

That's what `throw!` does:

```ruby
class GenerateReport < CMDx::Task
  def work
    validation_result = ValidateData.execute(context)

    if validation_result.failed?
      throw!(validation_result)  # Propagates the failure
    end

    # Only runs if validation succeeded
    generate_report
  end
end
```

The `throw!` method copies the state, status, reason, and metadata from the subtask result. The failure bubbles up with full context about where it originated.

### Conditional Propagation

You can be selective about what you propagate:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Always throw failures
    inventory_result = CheckInventory.execute(context)
    throw!(inventory_result) if inventory_result.failed?

    # Only throw skips for certain conditions
    shipping_result = CalculateShipping.execute(context)
    if shipping_result.skipped? && context.requires_shipping
      throw!(shipping_result)
    end

    finalize_order
  end
end
```

### Enriching Propagated Failures

Add metadata when propagating:

```ruby
class BatchProcessor < CMDx::Task
  def work
    step_result = ProcessItem.execute(context)

    if step_result.failed?
      throw!(
        step_result,
        batch_stage: "item_processing",
        item_index: context.current_index
      )
    end
  end
end
```

The metadata merges with the original failure's metadata, giving you a complete picture.

## Tracing Failures Through Chains

When a failure propagates through multiple tasks, you can trace its origin:

```ruby
result = OrderWorkflow.execute(invalid_order_data)

if result.failed?
  # Find the original failure
  original = result.caused_failure
  if original
    puts "Original failure: #{original.task.class.name}"
    puts "Reason: #{original.reason}"
  end

  # Find what propagated it
  thrower = result.threw_failure
  if thrower && thrower != original
    puts "Propagated by: #{thrower.task.class.name}"
  end

  # Determine failure type
  if result.caused_failure?
    puts "This task was the original source"
  elsif result.thrown_failure?
    puts "This task failed due to propagation"
  end
end
```

This is incredibly useful for debugging complex workflows. Instead of "order processing failed," you get "ValidateAddress failed with 'Invalid ZIP code', propagated through ProcessShipping."

## State and Status Transitions

Understanding the state model helps you handle results correctly:

| Method | State | Status | `good?` | `bad?` |
|--------|-------|--------|---------|--------|
| (success) | `complete` | `success` | `true` | `false` |
| `skip!` | `interrupted` | `skipped` | `true` | `true` |
| `fail!` | `interrupted` | `failed` | `false` | `true` |

The key distinction:
- **State** tells you *how* execution ended (complete vs interrupted)
- **Status** tells you *what* the outcome was (success, skipped, failed)
- **`good?`** means "not a failure" (success or skip)
- **`bad?`** means "not a success" (skip or fail)

Use these for conditional logic:

```ruby
result = ProcessOrder.execute(order_id: 123)

case result.status
when "success"
  puts "Order processed: #{result.context.order.id}"
when "skipped"
  puts "Order skipped: #{result.reason}"
when "failed"
  puts "Order failed: #{result.reason}"
  handle_failure(result.metadata[:error_code])
end
```

Or with the `on` callback:

```ruby
ProcessOrder.execute(order_id: 123)
  .on(:success) { |r| notify_customer(r.context.order) }
  .on(:skipped) { |r| log_skip(r.reason) }
  .on(:failed)  { |r| alert_support(r) }
```

## Best Practices

After building dozens of Ruby applications with CMDx, here's what I've learned:

### 1. Always Provide Reasons

```ruby
# Good: Clear, actionable
fail!("Payment declined: insufficient funds", code: :insufficient_funds)
skip!("Order already shipped on #{order.shipped_at}")

# Bad: Vague, unhelpful
fail!("Error")
skip!  # Uses default "Unspecified"
```

### 2. Use Metadata for Machine-Readable Context

```ruby
fail!(
  "Rate limit exceeded",
  error_code: "RATE_LIMIT",
  retry_after: 60,
  requests_remaining: 0
)
```

### 3. Prefer `skip!` Over Early Returns

```ruby
# Good: Intent is clear
if already_processed?
  skip!("Already processed")
end

# Bad: Silent no-op, unclear intent
return if already_processed?
```

### 4. Use `execute` for Most Cases, `execute!` for Critical Paths

```ruby
# Most code: result-based flow
result = ProcessOrder.execute(order_id: id)
handle_result(result)

# Critical paths: exception-based control
def create_account
  CreateUser.execute!(params)  # Failure = controller exception
  redirect_to dashboard_path
end
```

### 5. Match Faults Specifically When It Matters

```ruby
begin
  Workflow.execute!(data)
rescue CMDx::FailFault.for?(CriticalTask) => e
  escalate_immediately(e)  # Critical tasks need immediate attention
rescue CMDx::Fault => e
  standard_error_handling(e)  # Everything else
end
```

That's the power of CMDx interruptions: explicit control flow, rich context, and clean error handling. No more mystery failures at 2 AM.

Happy coding!
