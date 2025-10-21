# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

Check out the [Getting Started](getting_started.md#middlewares) docs for global configuration.

## Order

Middleware executes in a nested fashion, creating an onion-like execution pattern:

!!! note

    Middleware executes in the order they are registered, with the first registered middleware being the outermost wrapper.

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

Class and Module based declarations can be removed at a global and task level.

!!! warning

    Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class ProcessCampaign < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, TelemetryMiddleware
end
```

## Built-in

### Timeout

Ensures task execution doesn't exceed a specified time limit:

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

Tags tasks with a global correlation ID for distributed tracing:

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

The runtime middleware tags tasks with how long it took to execute the task.
The calculation uses a monotonic clock and the time is returned in milliseconds.

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
