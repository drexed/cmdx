# Middlewares

Middlewares provide a Rack-style wrapper system around task execution, enabling cross-cutting concerns like logging, authentication, caching, and error handling. Middleware can wrap task execution to provide additional functionality while maintaining clean separation of concerns.

## Key Features

- **Rack-style Architecture**: Familiar middleware pattern for Ruby developers
- **Execution Wrapping**: Wrap task execution with before/after logic
- **Short-circuiting**: Middleware can halt execution and return early
- **Flexible Types**: Support class, instance, and proc-based middleware
- **Inheritance Support**: Middleware is inherited from parent task classes
- **Composable Stack**: Build complex behavior by composing simple middleware

> [!TIP]
> Middleware is inheritable, making it perfect for setting up global cross-cutting concerns like authentication, logging, metrics collection, or error handling across all tasks.

## Middleware Declaration

```ruby
class ProcessOrderTask < CMDx::Task
  # Class-based middleware
  use AuthenticationMiddleware
  use LoggingMiddleware
  use CachingMiddleware, ttl: 300

  def call
    # Business logic implementation
  end
end
```

## Middleware Types

CMDx supports three types of middleware, each with different use cases:

### Class Middleware

```ruby
class LoggingMiddleware < CMDx::Middleware
  def initialize(level: :info)
    @level = level
  end

  def call(task, callable)
    Rails.logger.public_send(@level, "Starting #{task.class.name}")

    result = callable.call(task)

    Rails.logger.public_send(@level, "Finished #{task.class.name}: #{result.status}")
    result
  end
end

class ProcessOrderTask < CMDx::Task
  use LoggingMiddleware, level: :debug

  def call
    # Business logic
  end
end
```

### Instance Middleware

```ruby
class ProcessOrderTask < CMDx::Task
  use LoggingMiddleware.new(level: :warn)

  def call
    # Business logic
  end
end
```

### Proc Middleware

```ruby
class ProcessOrderTask < CMDx::Task
  use proc { |task, callable|
    puts "Before task execution"
    result = callable.call(task)
    puts "After task execution"
    result
  }

  def call
    # Business logic
  end
end
```

## Execution Order

Middleware executes in a nested fashion, with the first declared middleware wrapping all subsequent middleware and the task execution:

```ruby
class ProcessOrderTask < CMDx::Task
  use FirstMiddleware      # Outermost wrapper
  use SecondMiddleware     # Middle wrapper
  use ThirdMiddleware      # Innermost wrapper

  def call
    # Core business logic
  end
end

# Execution flow:
# 1. FirstMiddleware before
# 2.   SecondMiddleware before
# 3.     ThirdMiddleware before
# 4.       [task.call method]
# 5.     ThirdMiddleware after
# 6.   SecondMiddleware after
# 7. FirstMiddleware after
```

> [!IMPORTANT]
> Middleware executes in declaration order for "before" logic and reverse order for "after" logic, creating a nested execution pattern.

## Short-circuiting Execution

Middleware can halt execution by not calling the next middleware in the chain:

```ruby
class AuthenticationMiddleware < CMDx::Middleware
  def call(task, callable)
    unless task.context.user&.authenticated?
      task.fail!(reason: "Authentication required")
      return task.result
    end

    callable.call(task)
  end
end

class ProcessOrderTask < CMDx::Task
  use AuthenticationMiddleware

  def call
    # This will only execute if authentication passes
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

## Middleware Inheritance

Middleware is inherited from parent classes, enabling architectural patterns:

```ruby
class ApplicationTask < CMDx::Task
  # Global middleware for all tasks
  use RequestIdMiddleware
  use LoggingMiddleware
  use MetricsMiddleware
end

class ProcessOrderTask < ApplicationTask
  # Inherits all ApplicationTask middleware plus these specific ones
  use AuthenticationMiddleware
  use CachingMiddleware, ttl: 300

  def call
    # Business logic
  end
end
```

## Practical Examples

### Authentication Middleware

```ruby
class AuthenticationMiddleware < CMDx::Middleware
  def initialize(required_role: nil)
    @required_role = required_role
  end

  def call(task, callable)
    user = task.context.current_user

    unless user&.authenticated?
      task.fail!(reason: "Authentication required")
      return task.result
    end

    if @required_role && !user.has_role?(@required_role)
      task.fail!(reason: "Insufficient permissions")
      return task.result
    end

    callable.call(task)
  end
end
```

### Monitoring Middleware

```ruby
class MonitoringMiddleware < CMDx::Middleware
  def call(task, callable)
    result = callable.call(task)

    MetricsService.record_success(
      task: task.class.name,
      duration: result.runtime
    )

    result
  rescue => error
    MetricsService.record_failure(
      task: task.class.name,
      duration: Time.current - start_time,
      error: error.class.name
    )

    raise
  end
end
```

## Advanced Patterns

### Conditional Middleware

```ruby
class ConditionalCachingMiddleware < CMDx::Middleware
  def call(task, callable)
    if task.context.cache_enabled?
      cache_key = "task:#{task.class.name}:#{task.context.cache_key}"

      cached_result = Rails.cache.read(cache_key)
      return cached_result if cached_result

      result = callable.call(task)

      Rails.cache.write(cache_key, result, expires_in: 1.hour) if result.success?
      result
    else
      callable.call(task)
    end
  end
end
```

### Context Modification

```ruby
class RequestContextMiddleware < CMDx::Middleware
  def call(task, callable)
    # Add request context information
    task.context.request_id = SecureRandom.uuid
    task.context.started_at = Time.current
    task.context.environment = Rails.env

    result = callable.call(task)

    # Add completion information
    task.context.completed_at = Time.current
    task.context.duration = task.context.completed_at - task.context.started_at

    result
  end
end
```

### Retry Middleware

```ruby
class RetryMiddleware < CMDx::Middleware
  def initialize(max_attempts: 3, backoff: 1.0)
    @max_attempts = max_attempts
    @backoff = backoff
  end

  def call(task, callable)
    attempts = 0

    begin
      attempts += 1
      callable.call(task)
    rescue StandardError => error
      if attempts < @max_attempts && retryable_error?(error)
        sleep(@backoff * attempts)
        retry
      else
        raise
      end
    end
  end

  private

  def retryable_error?(error)
    error.is_a?(Net::TimeoutError) ||
    error.is_a?(Net::HTTPServerException)
  end
end
```

## Best Practices

### Middleware Design

- **Single Responsibility**: Each middleware should handle one concern
- **Fail Fast**: Validate conditions early and short-circuit when appropriate
- **Preserve Context**: Avoid modifying task context unless necessary
- **Handle Errors Gracefully**: Consider how errors should propagate through the stack

### Performance Considerations

- **Minimize Overhead**: Keep middleware logic lightweight
- **Avoid Blocking Operations**: Use async processing when possible
- **Cache Expensive Operations**: Store results when they can be reused
- **Monitor Execution Time**: Track middleware performance in production

### Error Handling

- **Propagate Appropriately**: Decide whether to handle, transform, or propagate errors
- **Log Contextually**: Include relevant task and middleware information
- **Maintain Stack Integrity**: Ensure middleware doesn't break the execution chain
- **Use Result Objects**: Prefer task.fail!() over raising exceptions when possible

### Registry Management

- **Array-like Operations**: Use standard Array methods for inspection and manipulation
- **Inheritance Aware**: Consider how middleware inheritance affects behavior
- **Order Dependent**: Be mindful of middleware execution order
- **Environment Specific**: Use different middleware for different environments
- **Testing Isolation**: Use `clear` method to reset middleware collection in tests

---

- **Prev:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
- **Next:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
