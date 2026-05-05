---
date: 2026-05-06
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-patterns-debugging-and-observability
---

# CMDx Patterns: Debugging and Observability

*Part 4 of the CMDx Patterns series*

*Targets CMDx v1.21.*

It's 2 AM. Your pager fires. A customer reports that their order went through but they never got a confirmation email. You open your log aggregator and search for the user ID. In a typical Rails app, you'd find a scattered trail of `puts`-style logs, maybe a Sentry exception if you're lucky, and no clear picture of what actually happened.

With CMDx, you search for the `chain_id` and see every task that ran, in order, with timing, status, and metadata. The confirmation email task shows `status: "skipped"`, `reason: "User unsubscribed from order notifications"`. Mystery solved in under a minute.

That's the power of observability built into the framework. This post covers how to use CMDx's logging, chain correlation, result inspection, and tagging to debug problems fast—in both development and production.

<!-- more -->

## The Automatic Log

Every CMDx task execution produces a log entry. You don't configure this, you don't opt into it—it happens:

```ruby
class CreateUser < CMDx::Task
  required :email, presence: true

  def work
    context.user = User.create!(email: email)
  end
end

CreateUser.execute(email: "ada@example.com")
```

Log output (using the Line formatter):

```log
I, [2026-05-13T10:00:00.000000Z #1234] INFO -- cmdx: {index: 0, chain_id: "abc123", type: "Task", tags: [], class: "CreateUser", dry_run: false, id: "def456", state: "complete", status: "success", outcome: "success", metadata: {runtime: 12}}
```

Every entry includes:

| Field | Purpose |
|-------|---------|
| `chain_id` | Links related task executions |
| `class` | Which task ran |
| `state` | Lifecycle state (complete, interrupted) |
| `status` | Business outcome (success, skipped, failed) |
| `metadata` | Custom data + runtime |
| `reason` | Why it failed or skipped (when applicable) |
| `caused_failure` | Root cause in workflows |
| `threw_failure` | Which task propagated the failure |

When a task fails, the log captures everything you need:

```log
I, [2026-05-13T10:00:01.000000Z #1234] INFO -- cmdx: {index: 0, chain_id: "abc123", class: "CreateUser", state: "interrupted", status: "failed", metadata: {errors: {messages: {email: ["can't be blank"]}}}, reason: "Invalid", cause: #<CMDx::FailFault: Invalid>}
```

No extra code. No logging statements to remember. It's always there.

## Chain Correlation: The Killer Feature

When one task calls another—whether through a workflow or direct invocation—they share the same `chain_id`. This is the single most useful debugging feature in CMDx.

### Tracing a Workflow

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task ValidateCart
  task CreateOrder
  task ChargePayment
  task SendConfirmation
end

PlaceOrder.execute(user: user, cart: cart)
```

Your logs show:

```json
{"index":1,"chain_id":"abc123","class":"ValidateCart","status":"success","metadata":{"runtime":5}}
{"index":2,"chain_id":"abc123","class":"CreateOrder","status":"success","metadata":{"runtime":34}}
{"index":3,"chain_id":"abc123","class":"ChargePayment","status":"failed","metadata":{"code":"card_declined","runtime":892},"reason":"Card declined"}
{"index":0,"chain_id":"abc123","class":"PlaceOrder","status":"failed","reason":"Card declined","caused_failure":{"class":"ChargePayment"}}
```

Filter by `chain_id: "abc123"` and you see the entire request lifecycle. The `index` field gives you execution order. The final entry (the workflow itself, always `index: 0`) summarizes the outcome and points to the root cause.

### Tracing Task-in-Task Calls

Chains work without workflows too. Any task calling another task within the same thread shares the chain:

```ruby
class Accounts::Onboard < CMDx::Task
  def work
    Accounts::Create.execute(email: context.email)
    Accounts::SetupProfile.execute(context)
    Notifications::SendWelcome.execute(user: context.user)
  end
end
```

All four tasks (parent + 3 subtasks) share one `chain_id`. You get the same tracing capability without declaring a workflow.

### Thread Safety

Chains are thread-local. Parallel requests never cross-contaminate:

```ruby
# Request A (Thread 1)
PlaceOrder.execute(...)  # chain_id: "aaa111"

# Request B (Thread 2)
PlaceOrder.execute(...)  # chain_id: "bbb222"
```

Each thread has its own chain. No race conditions, no interleaved logs.

## Custom Logging Inside Tasks

The automatic log covers execution lifecycle. For business-level events, use the built-in `logger`:

```ruby
class Billing::ProcessPayment < CMDx::Task
  required :order
  required :user

  def work
    logger.info "Contacting payment gateway for order #{order.id}"

    charge = PaymentGateway.charge(
      amount: order.total_cents,
      customer: user.stripe_customer_id
    )

    logger.info "Payment successful: charge #{charge.id}, amount #{order.total_cents}"
    context.charge = charge
  end
end
```

These custom log entries use the same logger instance as the framework, so they interleave correctly with the automatic execution logs. If you've configured JSON formatting, your custom logs are JSON too.

## Tags for Filtering

Tags categorize tasks for log filtering and metrics:

```ruby
class Billing::ChargeCard < CMDx::Task
  settings(tags: ["billing", "payments", "stripe"])

  def work
    # ...
  end
end
```

Tags appear in every log entry:

```json
{"chain_id":"abc123","class":"Billing::ChargeCard","tags":["billing","payments","stripe"],"status":"success"}
```

In your log aggregator:

```
tags:"billing" AND status:"failed" | stats count by class
```

Instantly see which billing tasks are failing most.

## Formatter Selection

Choose the formatter that matches your infrastructure:

```ruby
CMDx.configure do |config|
  # Human-readable for development
  config.logger.formatter = CMDx::LogFormatters::Line.new

  # Structured JSON for Datadog/Splunk/CloudWatch
  config.logger.formatter = CMDx::LogFormatters::Json.new

  # Key-value pairs for grep-friendly parsing
  config.logger.formatter = CMDx::LogFormatters::KeyValue.new

  # ELK stack with @timestamp/@version
  config.logger.formatter = CMDx::LogFormatters::Logstash.new
end
```

Override per-task for verbose debugging in specific areas:

```ruby
class Troublesome::Task < CMDx::Task
  settings(log_level: :debug, log_formatter: CMDx::LogFormatters::Json.new)

  def work
    logger.debug { "Detailed state: #{context.to_h.inspect}" }
    # ...
  end
end
```

## Result Inspection

When debugging in a console or test, the result object is your best friend.

### Basic Inspection

```ruby
result = PlaceOrder.execute(user: user, cart: cart)

result.state      #=> "interrupted"
result.status     #=> "failed"
result.reason     #=> "Card declined"
result.metadata   #=> { code: "card_declined" }
result.cause      #=> #<CMDx::FailFault: Card declined>
```

### Chain Inspection

Walk the entire execution chain:

```ruby
result.chain.results.each do |r|
  puts "#{r.index}: #{r.task.class.name} → #{r.status} (#{r.metadata[:runtime]}ms)"
end

# 0: PlaceOrder → failed
# 1: ValidateCart → success (5ms)
# 2: CreateOrder → success (34ms)
# 3: ChargePayment → failed (892ms)
```

### Failure Tracing

Find who caused the failure and who propagated it:

```ruby
if result.failed?
  if original = result.caused_failure
    puts "Root cause: #{original.task.class.name}"
    puts "Reason: #{original.reason}"
    puts "Metadata: #{original.metadata}"
  end

  if thrower = result.threw_failure
    puts "Propagated by: #{thrower.task.class.name}"
  end
end
```

### Pattern Matching

Ruby's pattern matching makes result inspection expressive:

```ruby
case result
in { status: "failed", metadata: { code: "card_declined" } }
  puts "Payment issue — check Stripe dashboard"
in { status: "failed", metadata: { errors: { messages: Hash => msgs } } }
  puts "Validation errors: #{msgs}"
in { status: "skipped", reason: String => reason }
  puts "Skipped: #{reason}"
in { status: "success" }
  puts "All good"
end
```

## Correlation Middleware

For distributed tracing across HTTP boundaries, use the built-in `Correlate` middleware:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate
end
```

Each execution gets a `correlation_id` in its metadata:

```ruby
result = MyTask.execute(...)
result.metadata[:correlation_id]  #=> "550e8400-e29b-41d4-a716-446655440000"
```

Pass it across service boundaries:

```ruby
class Api::Webhook < CMDx::Task
  def work
    CMDx::Middlewares::Correlate.use(context.request_id) do
      ProcessWebhook.execute(context)
      SyncExternalSystem.execute(context)
    end
  end
end
```

Every task inside the `use` block shares the same `correlation_id`, even if they start new chains. This bridges the gap between chain IDs (single-thread) and request tracing (cross-service).

## Backtraces

For non-fault exceptions, enable backtraces to see where things went wrong:

```ruby
CMDx.configure do |config|
  config.backtrace = true
  config.backtrace_cleaner = Rails.backtrace_cleaner.method(:clean)
end
```

Or per-task:

```ruby
class Flaky::ExternalCall < CMDx::Task
  settings(backtrace: true)

  def work
    ExternalApi.call(context.params)
  end
end
```

When an exception is caught by `execute`, the backtrace appears in the log entry, cleaned by your backtrace cleaner. This is invaluable for exceptions you can't reproduce locally.

## The Debugging Workflow

Here's how I debug a CMDx failure in production:

**1. Get the chain ID.** From the error report, API response, or Sentry breadcrumb, find the `chain_id`.

**2. Query all entries for that chain:**

```
chain_id:"abc123" | sort index
```

**3. Identify the failed task.** Look for `status:"failed"` entries. The one with `caused_failure` data is the root cause.

**4. Examine metadata.** The `metadata` field contains error codes, validation messages, and any custom data you passed to `fail!`.

**5. Check timing.** If `metadata.runtime` is abnormally high, you've found a performance issue masquerading as a failure (likely a timeout).

**6. Reproduce locally.** Take the context data from the log, construct the inputs, and run the failing task in a console:

```ruby
result = Billing::ChargeCard.execute(
  customer_id: 42,
  amount_cents: 5000
)
puts result.reason
puts result.metadata
puts result.cause&.backtrace&.first(5)
```

This workflow consistently gets me from "something broke" to "here's why" in under five minutes. Before CMDx, the same investigation could take hours.

## Key Takeaways

1. **Every execution is logged.** You never have to wonder if a task ran. It's in the log.

2. **Chain IDs are your best friend.** One ID links every task in a request. Filter by it and see the full picture.

3. **Tags enable aggregate analysis.** Categorize tasks by domain, criticality, or team ownership.

4. **Results carry everything.** State, status, reason, metadata, cause, chain, failure tracing—it's all on the result object.

5. **Choose the right formatter.** JSON for production aggregation, Line for development, Logstash for ELK.

6. **Correlation bridges services.** The `Correlate` middleware extends tracing across HTTP and async boundaries.

Observability isn't something you add after the fact. With CMDx, it's the foundation everything else is built on.

Happy coding!

## References

- [Logging](https://drexed.github.io/cmdx/logging/)
- [Chain](https://drexed.github.io/cmdx/basics/chain/)
- [Result](https://drexed.github.io/cmdx/outcomes/result/)
- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
