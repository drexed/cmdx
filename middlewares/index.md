# Middlewares

Wrap task execution with middleware for cross-cutting concerns like authentication, caching, timeouts, and monitoring. Think Rack middleware, but for your business logic.

See [Global Configuration](getting_started.md#middlewares) for framework-wide setup.

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
result.status   #=> "failure"
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
result.metadata #=> { runtime: 1247 } (ms)
```
