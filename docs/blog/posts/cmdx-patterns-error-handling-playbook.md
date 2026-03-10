---
date: 2026-04-29
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-patterns-error-handling-playbook
---

# CMDx Patterns: The Error Handling Playbook

*Part 3 of the CMDx Patterns series*

I used to think error handling was simple. Something goes wrong, you rescue it, done. Then I started building systems where "something went wrong" had fifteen different flavors—each requiring a different response. A missing record is not the same as a network timeout. A user's expired subscription is not the same as a billing system outage. Treating them identically is how you end up with generic "Something went wrong" error pages and support tickets that take hours to triage.

CMDx gives you four distinct mechanisms for handling problems: `skip!`, `fail!`, `throw!`, and letting exceptions propagate. Knowing which one to reach for—and when—is the difference between a system that degrades gracefully and one that falls over at the first sign of trouble.

<!-- more -->

## The Four Mechanisms

Here's the decision tree I follow for every error condition in a Ruby CMDx task:

| Situation | Mechanism | Result Status | `good?` |
|---|---|---|---|
| Nothing to do (expected, benign) | `skip!` | `skipped` | `true` |
| Business rule violation | `fail!` | `failed` | `false` |
| Subtask failure to propagate | `throw!` | `failed` | `false` |
| Unexpected exception | Let it raise | `failed` | `false` |

Let's look at each one in detail.

## skip! — "Nothing to Do Here"

`skip!` means the task recognized that execution isn't needed and stopped gracefully. It's a *successful outcome*—the task did exactly the right thing by not running.

**Use when:**

- The work was already done (idempotency)
- Preconditions make the task irrelevant
- Feature flags or business rules disable the operation

```ruby
class Notifications::SendReminder < CMDx::Task
  required :user_id, type: :integer

  def work
    user = User.find(user_id)

    skip!("User unsubscribed from reminders") unless user.reminders_enabled?
    skip!("Reminder already sent today") if user.reminded_today?

    ReminderMailer.daily(user).deliver_later
    context.reminded_at = Time.current
  end
end
```

The caller checks `result.skipped?` and moves on. No error handling needed, no retry logic—the system is in a valid state:

```ruby
result = Notifications::SendReminder.execute(user_id: 42)

if result.skipped?
  logger.info "Skipped: #{result.reason}"
  # That's fine. Nothing to do.
end
```

### Skip vs. Early Return

I see people writing `return if condition` inside `work`. Don't—that silently succeeds without recording why:

```ruby
# Bad: silent success, no trace
def work
  return unless user.active?
  # ...
end

# Good: explicit skip with reason
def work
  skip!("User is inactive") unless user.active?
  # ...
end
```

The skip shows up in logs, in the result object, and in workflow chain analysis. The early return vanishes.

## fail! — "This Can't Proceed"

`fail!` means a business rule prevented completion. The task tried (or evaluated) and determined that execution should stop with a failure. This is a *controlled, intentional failure*—not an exception.

**Use when:**

- Input passes validation but violates a business rule
- An external condition makes the operation invalid
- You want structured failure metadata for the caller

```ruby
class Orders::ApplyDiscount < CMDx::Task
  required :order
  required :discount_code, presence: true

  def work
    discount = Discount.find_by(code: discount_code)

    if discount.nil?
      fail!("Unknown discount code", code: :not_found)
    elsif discount.expired?
      fail!("Discount expired", code: :expired, expired_at: discount.expired_at)
    elsif discount.usage_limit_reached?
      fail!("Discount usage limit reached", code: :exhausted, uses: discount.usage_count)
    elsif order.total < discount.minimum_order
      fail!("Order total below minimum",
        code: :below_minimum, minimum: discount.minimum_order, total: order.total)
    end

    order.apply_discount!(discount)
    context.discount_amount = discount.calculate(order.total)
  end
end
```

Each failure path carries structured metadata. The caller can pattern match on the code:

```ruby
result = Orders::ApplyDiscount.execute(order: order, discount_code: "SAVE20")

case result
in { status: "failed", metadata: { code: :not_found } }
  flash[:error] = "That discount code doesn't exist"
in { status: "failed", metadata: { code: :expired } }
  flash[:error] = "That code has expired"
in { status: "failed", metadata: { code: :exhausted } }
  flash[:error] = "That code has been fully redeemed"
in { status: "failed", metadata: { code: :below_minimum, minimum: BigDecimal => min } }
  flash[:error] = "Your order must be at least $#{min} to use this code"
in { status: "success" }
  flash[:notice] = "Discount applied!"
end
```

### fail! with Manual Errors

For multi-field validation failures, accumulate errors before failing:

```ruby
class Events::Reschedule < CMDx::Task
  required :event
  required :new_start, type: :datetime
  required :new_end, type: :datetime

  def work
    errors.add(:new_start, "must be in the future") if new_start < Time.current
    errors.add(:new_end, "must be after start") if new_end <= new_start
    errors.add(:event, "cannot reschedule a cancelled event") if event.cancelled?
    errors.add(:event, "too close to start time") if event.starts_at - Time.current < 24.hours

    fail!("Rescheduling failed") if errors.any?

    event.update!(starts_at: new_start, ends_at: new_end)
    context.rescheduled_at = Time.current
  end
end
```

All errors are collected before halting. The caller gets every problem in one response.

## throw! — "Someone Else Failed"

`throw!` propagates a subtask's failure up to the parent task. It preserves the original failure's context, reason, and metadata while recording the propagation chain.

**Use when:**

- A subtask fails and the parent can't recover
- You want the parent to fail with the subtask's reason
- You need to trace failure origin through nested tasks

```ruby
class Subscriptions::Renew < CMDx::Task
  required :subscription_id, type: :integer

  def work
    subscription = Subscription.find(subscription_id)
    context.subscription = subscription

    payment_result = Billing::ChargeCard.execute(
      customer_id: subscription.user_id,
      amount_cents: subscription.plan.price_cents
    )
    throw!(payment_result) if payment_result.failed?

    subscription.renew!
    context.renewed_at = Time.current
  end
end
```

When the payment fails, `throw!` makes `Subscriptions::Renew` fail too—but the chain analysis shows that `Billing::ChargeCard` was the *root cause*, not the renewal task:

```ruby
result = Subscriptions::Renew.execute(subscription_id: 99)

result.failed?                          #=> true
result.caused_failure.task.class.name   #=> "Billing::ChargeCard"
result.caused_failure.reason            #=> "Card expired"
result.threw_failure.task.class.name    #=> "Subscriptions::Renew"
```

### throw! with Additional Metadata

Add context about why the propagation matters:

```ruby
def work
  validation_result = DataValidator.execute(context)

  if validation_result.failed?
    throw!(validation_result, {
      stage: "pre-processing",
      can_retry: false,
      suggestion: "Check input format"
    })
  end
end
```

### throw! vs. fail! for Subtask Failures

This is the most common mistake I see. When a subtask fails, developers reach for `fail!`:

```ruby
# Bad: loses the subtask's failure context
payment_result = Billing::ChargeCard.execute(...)
if payment_result.failed?
  fail!(payment_result.reason)  # original metadata, chain info, and cause are lost
end

# Good: preserves everything
payment_result = Billing::ChargeCard.execute(...)
throw!(payment_result) if payment_result.failed?
```

`throw!` is purpose-built for this. Use it.

### Conditional Propagation

Sometimes you only want to propagate certain failures:

```ruby
def work
  result = ExternalApi::FetchData.execute(context)

  throw!(result) if result.failed?         # propagate failures
  # Don't propagate skips — that's fine, we'll use cached data
  context.data = result.skipped? ? CachedData.fetch(context.key) : result.context.data
end
```

## Exceptions — "Something Unexpected Happened"

Real exceptions—`ActiveRecord::RecordNotFound`, `Net::ReadTimeout`, `JSON::ParserError`—are unexpected situations that your code didn't anticipate as a business rule.

With `execute`, CMDx catches them and wraps them in a failed result:

```ruby
result = ProcessImport.execute(file_path: "/missing/file.csv")

result.failed?  #=> true
result.reason   #=> "[Errno::ENOENT] No such file or directory"
result.cause    #=> #<Errno::ENOENT: No such file or directory>
```

With `execute!`, they propagate naturally:

```ruby
begin
  ProcessImport.execute!(file_path: "/missing/file.csv")
rescue Errno::ENOENT => e
  # Handle missing file
rescue CMDx::FailFault => e
  # Handle business logic failure (fail! or validation)
rescue CMDx::SkipFault => e
  # Handle intentional skip
end
```

### Exception Handlers for APM

Register a global exception handler to report to your APM without changing task code:

```ruby
CMDx.configure do |config|
  config.exception_handler = proc do |task, exception|
    Sentry.capture_exception(exception, extra: {
      task: task.class.name,
      task_id: task.id,
      chain_id: task.chain.id
    })
  end
end
```

This runs for every non-fault `StandardError` caught by `execute`. Faults (from `skip!`/`fail!`) don't trigger it—they're intentional.

## Building an Error Taxonomy

For large applications, establish a consistent error vocabulary across your team.

### Error Codes

Standardize error codes with a namespace convention:

```ruby
# Domain.Subdomain.Specific
fail!("Card declined", code: "BILLING.PAYMENT.DECLINED")
fail!("Insufficient funds", code: "BILLING.PAYMENT.NSF")
fail!("Rate limit exceeded", code: "API.RATE_LIMIT.EXCEEDED")
fail!("User not found", code: "USERS.LOOKUP.NOT_FOUND")
```

### Severity Classification

Use metadata to classify failure severity:

```ruby
fail!("Service degraded", code: :degraded, severity: :warning, retryable: true)
fail!("Data corruption", code: :corrupted, severity: :critical, retryable: false)
fail!("Rate limited", code: :throttled, severity: :info, retryable: true, retry_after: 60)
```

Then handle based on severity:

```ruby
result = MyTask.execute(...)

if result.failed?
  case result.metadata[:severity]
  when :critical then PagerDuty.trigger(result.reason)
  when :warning  then Slack.notify("#alerts", result.reason)
  when :info     then logger.info(result.reason)
  end
end
```

## Handling Errors in Workflows

Workflows add another dimension: what happens when step 3 of 5 fails?

### Breakpoints

Control which statuses halt the pipeline:

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  # Stop on failure, continue on skip
  settings workflow_breakpoints: ["failed"]

  task ValidateCart
  task ReserveInventory    # might skip for digital orders
  task ChargePayment
  task SendConfirmation
end
```

### Tracing Workflow Failures

When a workflow fails, trace the root cause:

```ruby
result = PlaceOrder.execute(user: user, cart: cart)

if result.failed?
  root = result.caused_failure
  puts "Pipeline failed at: #{root.task.class.name}"
  puts "Reason: #{root.reason}"
  puts "Metadata: #{root.metadata}"

  case root.task
  when ChargePayment
    redirect_to payment_methods_path
  when ReserveInventory
    flash[:error] = "Some items are no longer available"
    redirect_to cart_path
  else
    flash[:error] = root.reason
    redirect_to checkout_path
  end
end
```

## The Complete Decision Tree

When you encounter a condition in your task, ask these questions in order:

1. **Is there nothing to do?** → `skip!("reason")`
2. **Is a business rule violated?** → `fail!("reason", code: :specific_code)`
3. **Did a subtask fail?** → `throw!(subtask_result)`
4. **Is this truly unexpected?** → Let the exception propagate

If you follow this consistently across your codebase, every failure will be categorized, traceable, and actionable.

Happy coding!

## References

- [Halt](https://drexed.github.io/cmdx/interruptions/halt/)
- [Faults](https://drexed.github.io/cmdx/interruptions/faults/)
- [Exceptions](https://drexed.github.io/cmdx/interruptions/exceptions/)
- [Result](https://drexed.github.io/cmdx/outcomes/result/)
