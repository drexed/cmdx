# Middlewares

Wrap task execution with middleware for cross-cutting concerns like authentication, caching, timeouts, and monitoring. Think Rack middleware, but for your business logic.

See [Global Configuration](configuration.md#middlewares) for framework-wide setup.

## Execution Order

Middleware wraps task execution in layers, like an onion:

!!! note

    First registered = outermost wrapper. They execute in registration order.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware         # 1st: outermost wrapper
  register :middleware, AuthorizationMiddleware # 2nd: middle wrapper
  register :middleware, CacheMiddleware         # 3rd: innermost wrapper

  def work
    # Your logic here...
  end
end

# Execution flow:
# 1. AuditMiddleware (before)
# 2.   AuthorizationMiddleware (before)
# 3.     CacheMiddleware (before)
# 4.       [task execution]
# 5.     CacheMiddleware (after)
# 6.   AuthorizationMiddleware (after)
# 7. AuditMiddleware (after)
```

## Declarations

### Proc or Lambda

Use anonymous functions for simple middleware logic:

```ruby
class ProcessCampaign < CMDx::Task
  # Proc
  register :middleware, proc do |task, options, &block|
    result = block.call
    Analytics.track(result.status)
    result
  end

  # Lambda
  register :middleware, ->(task, options, &block) {
    result = block.call
    Analytics.track(result.status)
    result
  }
end
```

### Class or Module

For complex middleware logic, use classes or modules:

```ruby
class TelemetryMiddleware
  def call(task, options)
    result = yield
    Telemetry.record(result.status)
  ensure
    result # Always return result
  end
end

class ProcessCampaign < CMDx::Task
  # Class or Module
  register :middleware, TelemetryMiddleware

  # Instance
  register :middleware, TelemetryMiddleware.new

  # With options
  register :middleware, MonitoringMiddleware, service_key: ENV["MONITORING_KEY"]
  register :middleware, MonitoringMiddleware.new(ENV["MONITORING_KEY"])
end
```

## Ordering

Control middleware insertion position with the `at:` parameter. First registered is outermost (default: append to end).

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware           # Position 0 (outermost)
  register :middleware, CacheMiddleware            # Position 1
  register :middleware, PriorityMiddleware, at: 0  # Inserted at position 0, pushes others down
end

# Execution order: PriorityMiddleware → AuditMiddleware → CacheMiddleware → [task] → ...
```

## Safety

CMDx detects middlewares that fail to yield or return the result. If a middleware swallows the block call, the task is automatically marked as failed with a descriptive error.

```ruby
class BrokenMiddleware
  def call(task, options)
    # Forgot to call `yield` — CMDx catches this
  end
end

result = MyTask.execute
result.failed? #=> true
result.reason  #=> "[RuntimeError] ..."
```

!!! danger "Caution"

    Always call `yield` inside your middleware and return the result. Swallowed execution is treated as a failure.

## Removals

Remove class or module-based middleware globally or per-task:

!!! warning

    Each `deregister` call removes one middleware. Use multiple calls for batch removals.

```ruby
class ProcessCampaign < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, TelemetryMiddleware
end
```

## Built-in

### Timeout

Prevent tasks from running too long:

```ruby
class ProcessReport < CMDx::Task
  # Default timeout: 3 seconds
  register :middleware, CMDx::Middlewares::Timeout

  # Seconds (takes Numeric, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, seconds: :max_processing_time

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, unless: -> { self.class.name.include?("Quick") }

  def work
    # Your logic here...
  end

  private

  def max_processing_time
    Rails.env.production? ? 2 : 10
  end
end

# Slow task
result = ProcessReport.execute

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "[CMDx::TimeoutError] execution exceeded 3 seconds"
result.cause    #=> <CMDx::TimeoutError>
result.metadata #=> { limit: 3 }
```

### Correlate

Add correlation IDs for distributed tracing and request tracking:

```ruby
class ProcessExport < CMDx::Task
  # Default correlation ID generation
  register :middleware, CMDx::Middlewares::Correlate

  # Seconds (takes Object, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, id: proc { |task| task.context.session_id }

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, if: :correlation_enabled?

  def work
    # Your logic here...
  end

  private

  def correlation_enabled?
    ENV["CORRELATION_ENABLED"] == "true"
  end
end

result = ProcessExport.execute
result.metadata #=> { correlation_id: "550e8400-e29b-41d4-a716-446655440000" }
```

#### Class-Level API

Manage correlation IDs directly for cross-boundary tracing (e.g., from a controller into multiple tasks):

```ruby
# Read or set the current correlation ID
CMDx::Middlewares::Correlate.id              #=> current ID or nil
CMDx::Middlewares::Correlate.id = "custom-id"

# Scoped block — restores the previous ID after the block
CMDx::Middlewares::Correlate.use("request-123") do
  ProcessExport.execute  # uses "request-123"
  SendNotification.execute # same correlation ID
end
# previous ID is restored here

# Clear the current ID
CMDx::Middlewares::Correlate.clear
```

### Runtime

Track task execution time in milliseconds using a monotonic clock:

```ruby
class PerformanceMonitoringCheck
  def call(task)
    task.context.tenant.monitoring_enabled?
  end
end

class ProcessExport < CMDx::Task
  # Default timeout is 3 seconds
  register :middleware, CMDx::Middlewares::Runtime

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Runtime, if: PerformanceMonitoringCheck
end

result = ProcessExport.execute
result.metadata #=> {
#   started_at: "2026-04-01T14:56:58Z",
#   ended_at: "2026-04-01T14:56:59Z"
#   runtime: 1247 (ms)
# } (ms)
```
