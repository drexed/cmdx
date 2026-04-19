---
date: 2026-04-22
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-patterns-advanced-middleware-stacks
---

# CMDx Patterns: Advanced Middleware Stacks

*Part 2 of the CMDx Patterns series*

*Targets CMDx v1.21.*

Middleware is one of those features that's easy to understand and hard to use well. You write a simple wrapper, register it, and it works. Then you write another. And another. Before long, you've got six middlewares on every task, they're firing in an order you didn't intend, and you're spending more time debugging the middleware stack than the business logic it wraps.

I've been through that cycle enough times to develop opinions about how to compose middleware stacks in CMDx. This post covers the patterns that survived contact with production Ruby applications—from simple wrappers to sophisticated multi-layer stacks.

<!-- more -->

## How Middleware Executes

Before we build anything complex, let's internalize the execution model. CMDx middleware works like Rack—first registered is outermost:

```ruby
class MyTask < CMDx::Task
  register :middleware, AuditMiddleware         # 1st: outermost
  register :middleware, AuthorizationMiddleware  # 2nd: middle
  register :middleware, CacheMiddleware          # 3rd: innermost

  def work
    # Your logic here
  end
end
```

Execution flows inward, then back out:

```
AuditMiddleware (before) →
  AuthorizationMiddleware (before) →
    CacheMiddleware (before) →
      [task.work]
    CacheMiddleware (after) ←
  AuthorizationMiddleware (after) ←
AuditMiddleware (after) ←
```

This matters because the outermost middleware sees the *final* result after all inner layers have run, while the innermost middleware sees the *raw* task output. Order your stack deliberately.

## The Five Essential Middlewares

After building dozens of CMDx applications, I've settled on five middlewares that cover most production needs.

### 1. Database Transaction

The most common middleware. Wrap mutations in a transaction and roll back on failure:

```ruby
class DatabaseTransaction
  def call(task, options)
    ActiveRecord::Base.transaction(requires_new: true) do
      yield.tap do |result|
        raise ActiveRecord::Rollback if result.failed?
      end
    end
  end
end
```

The `requires_new: true` is important—it creates a savepoint when transactions nest, so a failing subtask doesn't blow up the outer transaction.

### 2. Error Tracking

Report exceptions to your APM without interfering with task execution:

```ruby
class ErrorTracking
  def call(task, options)
    Sentry.with_scope do |scope|
      scope.set_tags(
        task_class: task.class.name,
        task_id: task.id,
        chain_id: task.chain.id
      )

      yield.tap do |result|
        if result.failed? && result.cause
          Sentry.capture_exception(result.cause)
        end
      end
    end
  rescue => e
    Sentry.capture_exception(e)
    raise
  end
end
```

Notice two error paths: exceptions that bubble up (the `rescue`) and controlled failures with a `cause` (the `tap` block). Both get reported, but only exceptions re-raise.

### 3. Circuit Breaker

Protect external service calls from cascading failures:

```ruby
class CircuitBreaker
  def call(task, options)
    service_name = options[:name] || task.class.name
    light = Stoplight(service_name)
    light.run { yield }
  rescue Stoplight::Error::RedLight => e
    task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e) }
  end
end
```

When the circuit opens, the task fails immediately without executing. No wasted API calls, no timeout waiting.

### 4. Instrumentation

Hook into ActiveSupport::Notifications for metrics and tracing:

```ruby
class Instrumentation
  def call(task, options)
    ActiveSupport::Notifications.instrument("execute.cmdx",
      task: task.class.name,
      task_id: task.id
    ) { yield }
  end
end
```

Subscribe once, observe everything:

```ruby
ActiveSupport::Notifications.subscribe("execute.cmdx") do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(2)
  StatsD.timing("cmdx.task.duration", duration, tags: ["task:#{payload[:task]}"])
end
```

### 5. Feature Flags

Gate task execution behind feature flags:

```ruby
class FeatureFlag
  def call(task, options)
    feature = options.fetch(:feature)
    actor = options[:actor]&.call || task.context[:user]

    if Flipper.enabled?(feature, actor)
      yield
    else
      task.result.tap { |r| r.skip!("Feature #{feature} is disabled") }
    end
  end
end
```

When the flag is off, the task skips cleanly—downstream code sees a `skipped` result, not an exception.

## Composing Stacks

Individual middlewares are simple. The art is in composition.

### Global Stack

Register middlewares that should wrap *every* task in your application:

```ruby
CMDx.configure do |config|
  config.middlewares.register Instrumentation
  config.middlewares.register ErrorTracking
end
```

Keep this minimal. Only truly universal concerns belong here.

### Base Class Stack

Layer domain-specific middleware in base classes:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, DatabaseTransaction
end

class ExternalApiTask < ApplicationTask
  register :middleware, CircuitBreaker
  register :middleware, CMDx::Middlewares::Timeout, seconds: 10
end

class Billing::BaseTask < ExternalApiTask
  deregister :middleware, CircuitBreaker              # remove the generic one
  register :middleware, CircuitBreaker, name: "stripe" # add Stripe-specific
end
```

The inheritance chain builds the stack: `Instrumentation → ErrorTracking → DatabaseTransaction → CircuitBreaker → Timeout`. Each layer adds its concern without repeating configuration.

### Per-Task Overrides

Some tasks need special treatment:

```ruby
class Reports::GenerateAnnual < ApplicationTask
  register :middleware, CMDx::Middlewares::Timeout, seconds: 120
  register :middleware, FeatureFlag, feature: :annual_reports

  def work
    # Long-running report generation
  end
end
```

The global and base class middlewares still apply. The per-task middlewares add to the stack.

### Removing Inherited Middleware

Sometimes a task shouldn't run inside a transaction:

```ruby
class Notifications::SendEmail < ApplicationTask
  deregister :middleware, DatabaseTransaction

  def work
    Mailer.deliver(context.email_params)
  end
end
```

Email delivery is idempotent and shouldn't roll back if a later database write fails.

## Middleware with Options

Options make middleware configurable per-registration:

```ruby
class RateLimiter
  def call(task, options)
    key = "cmdx:rate_limit:#{options[:scope] || task.class.name}"
    limit = options[:limit] || 100
    window = options[:window] || 60

    count = Redis.current.incr(key)
    Redis.current.expire(key, window) if count == 1

    if count > limit
      task.result.tap do |r|
        r.fail!("Rate limit exceeded",
          code: :rate_limited, limit: limit, window: window, retry_after: Redis.current.ttl(key))
      end
    else
      yield
    end
  end
end
```

```ruby
class Webhooks::Deliver < ApplicationTask
  register :middleware, RateLimiter, scope: "webhooks", limit: 1000, window: 3600

  def work
    HttpClient.post(context.url, context.payload)
  end
end

class Api::Search < ApplicationTask
  register :middleware, RateLimiter, scope: "api_search", limit: 50, window: 60

  def work
    context.results = SearchIndex.query(context.query)
  end
end
```

Same middleware, different configurations. The `options` hash makes it reusable across domains.

## Ordering with `at:`

When middleware order matters, use `at:` to control position:

```ruby
class CriticalTask < ApplicationTask
  register :middleware, AuditMiddleware           # Position 0
  register :middleware, CacheMiddleware            # Position 1
  register :middleware, PriorityMiddleware, at: 0  # Inserted at position 0
end

# Final order: PriorityMiddleware → AuditMiddleware → CacheMiddleware
```

I use this sparingly—if you need fine-grained ordering, your stack might be too complex.

## Real-World Stack: Payment Processing

Let me walk through a complete, production-grade middleware stack for payment processing:

```ruby
# Global: Every task gets these
CMDx.configure do |config|
  config.middlewares.register Instrumentation
  config.middlewares.register ErrorTracking
end

# Base: All tasks get a transaction
class ApplicationTask < CMDx::Task
  register :middleware, DatabaseTransaction
end

# External API tasks: Add resilience
class ExternalApiTask < ApplicationTask
  register :middleware, CMDx::Middlewares::Timeout, seconds: 15
end

# Billing: Stripe-specific resilience
class Billing::BaseTask < ExternalApiTask
  register :middleware, CircuitBreaker, name: "stripe"

  settings(
    retries: 3,
    retry_on: [Stripe::APIConnectionError, Net::OpenTimeout],
    retry_jitter: ->(retry_num) { 2**retry_num }
  )
end

# The actual task: clean business logic
class Billing::ChargeCard < Billing::BaseTask
  required :customer_id, type: :integer
  required :amount_cents, type: :integer, numeric: { min: 100 }

  returns :charge

  def work
    context.charge = Stripe::Charge.create(
      amount: amount_cents,
      customer: Customer.find(customer_id).stripe_id
    )
  end

  def rollback
    Stripe::Refund.create(charge: context.charge.id) if context.charge
  end
end
```

When `Billing::ChargeCard.execute(customer_id: 42, amount_cents: 5000)` runs, the execution flow is:

```
Instrumentation →
  ErrorTracking →
    DatabaseTransaction →
      Timeout (15s) →
        CircuitBreaker ("stripe") →
          [ChargeCard.work]
          (retries up to 3x with exponential backoff on Stripe connection errors)
```

If Stripe is down, the circuit breaker trips after enough failures. If it's slow, the timeout kills it. If it flakes, retries handle it. If it fails logically, the transaction rolls back. If anything unexpected happens, Sentry captures it. And instrumentation records the timing regardless.

The task itself? Four lines of business logic. Everything else is infrastructure, defined once in the inheritance chain.

## Anti-Patterns

### Too Many Middlewares Per Task

If a single task registers more than 3 middlewares, reconsider. Move shared concerns to base classes.

### Middleware That Modifies Context

Middleware should observe and wrap, not mutate business data. If you need to add data to context, use `before_execution` callbacks instead.

### Swallowing Exceptions

Always re-raise after logging. CMDx detects middlewares that forget to `yield` and marks the task as failed, but silent exception swallowing is harder to catch:

```ruby
# Bad
def call(task, options)
  yield
rescue => e
  Logger.error(e.message)  # swallowed!
end

# Good
def call(task, options)
  yield
rescue => e
  Logger.error(e.message)
  raise
end
```

## Key Takeaways

1. **Order matters.** First registered = outermost wrapper. Put observability outside, resilience inside.

2. **Layer via inheritance.** Global config → `ApplicationTask` → domain base class → individual task.

3. **Use options for configurability.** Same middleware class, different behavior per registration.

4. **Keep tasks clean.** Business logic in `work`, infrastructure in middleware. The task shouldn't know it's being timed, traced, or transacted.

5. **Deregister when needed.** Not every task needs every middleware. Opt out explicitly with `deregister`.

Middleware is the seam between your business logic and your infrastructure. Get the composition right and your tasks stay focused on what they do best—the work.

Happy coding!

## References

- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Configuration](https://drexed.github.io/cmdx/configuration/)
- [Tips and Tricks](https://drexed.github.io/cmdx/tips_and_tricks/)
