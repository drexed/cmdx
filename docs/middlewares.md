# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

## Table of Contents

- [Using Middleware](#using-middleware)
  - [Class Middleware](#class-middleware)
  - [Instance Middleware](#instance-middleware)
  - [Proc Middleware](#proc-middleware)
- [Execution Order](#execution-order)
- [Short-circuiting](#short-circuiting)
- [Inheritance](#inheritance)
- [Built-in Middleware](#built-in-middleware)
  - [Timeout Middleware](#timeout-middleware)
- [Writing Custom Middleware](#writing-custom-middleware)

## Using Middleware

Declare middleware using the `use` method in your task classes:

```ruby
class ProcessOrderTask < CMDx::Task
  use AuthenticationMiddleware
  use LoggingMiddleware, level: :info
  use CachingMiddleware, ttl: 300

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

### Class Middleware

The most common pattern - pass the middleware class with optional initialization arguments:

```ruby
class AuditMiddleware < CMDx::Middleware
  def initialize(action:, resource_type:)
    @action = action
    @resource_type = resource_type
  end

  def call(task, callable)
    result = callable.call(task)

    if result.success?
      AuditLog.create!(
        action: @action,
        resource_type: @resource_type,
        resource_id: task.context.id,
        user_id: task.context.current_user.id
      )
    end

    result
  end
end

class ProcessOrderTask < CMDx::Task
  use AuditMiddleware, action: 'process', resource_type: 'Order'

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

### Instance Middleware

Pre-configured middleware instances for complex initialization:

```ruby
class ProcessOrderTask < CMDx::Task
  use LoggingMiddleware.new(
    level: :debug,
    formatter: JSON::JSONFormatter.new,
    tags: ['order', 'payment']
  )

  def call
    # Business logic
  end
end
```

### Proc Middleware

Inline middleware for simple cases:

```ruby
class ProcessOrderTask < CMDx::Task
  use proc { |task, callable|
    start_time = Time.current
    result = callable.call(task)
    duration = Time.current - start_time

    Rails.logger.info "#{task.class.name} completed in #{duration}s"
    result
  }

  def call
    # Business logic
  end
end
```

## Execution Order

Middleware executes in nested fashion - first declared wraps all others:

```ruby
class ProcessOrderTask < CMDx::Task
  use TimingMiddleware         # 1st: outermost
  use AuthenticationMiddleware # 2nd: middle
  use ValidationMiddleware     # 3rd: innermost

  def call
    # Core logic executes last
  end
end

# Execution flow:
# 1. TimingMiddleware before
# 2.   AuthenticationMiddleware before
# 3.     ValidationMiddleware before
# 4.       [task execution]
# 5.     ValidationMiddleware after
# 6.   AuthenticationMiddleware after
# 7. TimingMiddleware after
```

> [!IMPORTANT]
> Middleware executes in declaration order for setup and reverse order for cleanup, creating proper nesting.

## Short-circuiting

Middleware can halt execution by not calling the next callable:

```ruby
class RateLimitMiddleware < CMDx::Middleware
  def initialize(limit: 100, window: 1.hour)
    @limit = limit
    @window = window
  end

  def call(task, callable)
    key = "rate_limit:#{task.context.current_user.id}"
    current_count = Rails.cache.read(key) || 0

    if current_count >= @limit
      task.fail!(reason: "Rate limit exceeded: #{@limit} requests per hour")
      return task.result
    end

    Rails.cache.write(key, current_count + 1, expires_in: @window)
    callable.call(task)
  end
end

class SendEmailTask < CMDx::Task
  use RateLimitMiddleware, limit: 50, window: 1.hour

  def call
    # Only executes if rate limit check passes
    EmailService.deliver(
      to: email_address,
      subject: subject,
      body: message_body
    )
  end
end
```

## Inheritance

Middleware is inherited from parent classes, enabling application-wide patterns:

```ruby
class ApplicationTask < CMDx::Task
  use RequestIdMiddleware      # All tasks get request tracking
  use PerformanceMiddleware    # All tasks get performance monitoring
  use ErrorReportingMiddleware # All tasks get error reporting
end

class ProcessOrderTask < ApplicationTask
  use AuthenticationMiddleware  # Specific to order processing
  use OrderValidationMiddleware # Domain-specific validation

  def call
    # Inherits all ApplicationTask middleware plus order-specific ones
  end
end
```

> [!TIP]
> Middleware is inherited by subclasses, making it ideal for setting up global concerns across all tasks in your application.

## Built-in Middleware

### Timeout Middleware

Enforces execution time limits:

```ruby
class ProcessLargeReportTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: 300 # 5 minutes

  def call
    # Long-running report generation
  end
end

# Conditional timeout
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout,
      seconds: 60,
      unless: -> { Rails.env.development? }

  def call
    # Business logic
  end
end
```

> [!WARNING]
> Tasks that exceed their timeout will be interrupted with a `CMDx::TimeoutError` and automatically marked as failed.

## Writing Custom Middleware

Inherit from `CMDx::Middleware` and implement the `call` method:

```ruby
class DatabaseTransactionMiddleware < CMDx::Middleware
  def call(task, callable)
    ActiveRecord::Base.transaction do
      result = callable.call(task)

      # Rollback transaction if task failed
      raise ActiveRecord::Rollback if result.failed?

      result
    end
  end
end

class CircuitBreakerMiddleware < CMDx::Middleware
  def initialize(failure_threshold: 5, reset_timeout: 60)
    @failure_threshold = failure_threshold
    @reset_timeout = reset_timeout
  end

  def call(task, callable)
    circuit_key = "circuit:#{task.class.name}"

    if circuit_open?(circuit_key)
      task.fail!(reason: "Circuit breaker is open")
      return task.result
    end

    result = callable.call(task)

    if result.failed?
      increment_failures(circuit_key)
    else
      reset_circuit(circuit_key)
    end

    result
  end

  private

  def circuit_open?(key)
    failures = Rails.cache.read("#{key}:failures") || 0
    failures >= @failure_threshold
  end

  def increment_failures(key)
    Rails.cache.increment("#{key}:failures", 1, expires_in: @reset_timeout)
  end

  def reset_circuit(key)
    Rails.cache.delete("#{key}:failures")
  end
end
```

---

- **Prev:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
- **Next:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
