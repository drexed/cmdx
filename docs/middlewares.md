# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

## Table of Contents

- [Order](#order)
- [Declarations](#declarations)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Removals](#removals)
- [Built-in](#built-in)
  - [Timeout](#timeout)
  - [Correlate](#correlate)
  - [Runtime](#runtime)

## Order

Middleware executes in a nested fashion, creating an onion-like execution pattern:

> [!IMPORTANT]
> Middleware executes in the order they are registered, with the first registered middleware being the outermost wrapper.

```ruby
class ProcessOrder < CMDx::Task
  register :middleware, TimingMiddleware         # 1st: outermost wrapper
  register :middleware, AuthenticationMiddleware # 2nd: middle wrapper
  register :middleware, ValidationMiddleware     # 3rd: innermost wrapper

  def work
    # Your logic here...
  end
end

# Execution flow:
# 1. TimingMiddleware (before)
# 2.   AuthenticationMiddleware (before)
# 3.     ValidationMiddleware (before)
# 4.       [task execution]
# 5.     ValidationMiddleware (after)
# 6.   AuthenticationMiddleware (after)
# 7. TimingMiddleware (after)
```

## Declarations

### Proc or Lambda

Use anonymous functions for simple middleware logic:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  register :middleware, proc do |task, options, &block|
    result = block.call
    APM.increment(result.status)
    result
  end

  # Lambda
  register :middleware, ->(task, options, &block) {
    result = block.call
    APM.increment(result.status)
    result
  }
end
```

### Class or Module

For complex middleware logic, use classes or modules:

```ruby
class MetricsMiddleware
  def call(task, options)
    result = yield
    APM.increment(result.status)
  ensure
    result # Always return result
  end
end

class ProcessOrder < CMDx::Task
  # Class or Module
  register :middleware, MetricsMiddleware

  # Instance
  register :middleware, MetricsMiddleware.new

  # With options
  register :middleware, AnalyticsMiddleware, api_key: ENV["ANALYTICS_API_KEY"]
  register :middleware, AnalyticsMiddleware.new(ENV["ANALYTICS_API_KEY"])
end
```

## Removals

Class, and Module based declarations can be removed at a global and task level.
Only one removal is allowed per invocation.

```ruby
class ProcessOrder < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, MetricsMiddleware
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Built-in

### Timeout

Ensures task execution doesn't exceed a specified time limit:

```ruby
class ProcessOrder < CMDx::Task
  # Default timeout: 3 seconds
  register :middleware, CMDx::Middlewares::Timeout

  # Seconds (takes Numeric, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, seconds: :max_execution_time

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, unless: -> { self.class.name.include?("Fast") }

  def work
    # Your logic here...
  end

  private

  def max_execution_time
    Rails.env.production? ? 1 : 5
  end
end

# Slow task
result = ProcessOrder.execute

result.state    #=> "interrupted"
result.status   #=> "failure"
result.reason   #=> "[CMDx::TimeoutError] execution exceeded 3 seconds"
result.cause    #=> <CMDx::TimeoutError>
result.metadata #=> { limit: 3 }
```

### Correlate

Tags tasks with a global correlation ID for distributed tracing:

```ruby
class ProcessOrder < CMDx::Task
  # Default correlation ID generation
  register :middleware, CMDx::Middlewares::Correlate

  # Seconds (takes Object, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, id: proc { |task| task.context.request_id }

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, if: :tracing_enabled?

  def work
    # Your logic here...
  end

  private

  def tracing_enabled?
    ENV["TRACING_ENABLED"] == "true"
  end
end

result = ProcessOrder.execute
result.metadata #=> { correlation_id: "550e8400-e29b-41d4-a716-446655440000" }
```

### Runtime

The runtime middleware tags tasks with how long it took to execute the task.
The calculation uses a monotonic clock and the time is returned in milliseconds.

```ruby
class SlowTaskCheck
  def call(task)
    task.context.account.debuggable?
  end
end

class ProcessOrder < CMDx::Task
  # Default timeout is 3 seconds
  register :middleware, CMDx::Middlewares::Runtime

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Runtime, if: SlowTaskCheck
end

result = ProcessOrder.execute
result.metadata #=> { runtime: 543 } (ms)
```

---

- **Prev:** [Callbacks](callbacks.md)
- **Next:** [Workflows](workflows.md)
