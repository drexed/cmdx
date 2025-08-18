# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

## Table of Contents

- [TLDR](#tldr)
- [Using Middleware](#using-middleware)
  - [Class Middleware](#class-middleware)
  - [Instance Middleware](#instance-middleware)
  - [Proc Middleware](#proc-middleware)
- [Execution Order](#execution-order)
- [Short-circuiting](#short-circuiting)
- [Inheritance](#inheritance)
- [Built-in Middleware](#built-in-middleware)
  - [Timeout Middleware](#timeout-middleware)
  - [Correlate Middleware](#correlate-middleware)
- [Writing Custom Middleware](#writing-custom-middleware)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Declare middleware with use method
use :middleware, AuthMiddleware, role: :admin      # Class with options
use :middleware, LoggingMiddleware.new(level: :debug)  # Instance
use :middleware, proc { |task, callable| ... }    # Proc

# Execution order: first declared wraps all others
use :middleware, OuterMiddleware    # Runs first/last
use :middleware, InnerMiddleware    # Runs last/first

# Built-in middleware
use :middleware, CMDx::Middlewares::Timeout, seconds: 30
use :middleware, CMDx::Middlewares::Correlate, id: "request-123"
```

## Using Middleware

> [!NOTE]
> Middleware executes in nested fashion around task execution. Use the `use` method to declare middleware in your task classes.

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
        user_id: task.context.current_user&.id
      )
    end

    result
  end
end

class ProcessOrder < CMDx::Task
  use :middleware, AuditMiddleware, action: 'process', resource_type: 'Order'

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

### Instance Middleware

Pre-configured middleware instances for complex initialization:

```ruby
class ProcessOrder < CMDx::Task
  use :middleware, LoggingMiddleware.new(
    level: :debug,
    formatter: CustomFormatter.new,
    tags: ['order', 'payment']
  )

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

### Proc Middleware

Inline middleware for simple cases:

```ruby
class ProcessOrder < CMDx::Task
  use :middleware, proc { |task, callable|
    start_time = Time.now
    result = callable.call(task)
    duration = Time.now - start_time

    Rails.logger.info "#{task.class.name} completed in #{duration.round(3)}s"
    result
  }

  def call
    # Business logic
  end
end
```

## Execution Order

> [!IMPORTANT]
> Middleware executes in nested fashion - first declared wraps all others, creating an onion-like execution pattern.

```ruby
class ProcessOrder < CMDx::Task
  use :middleware, TimingMiddleware         # 1st: outermost wrapper
  use :middleware, AuthenticationMiddleware # 2nd: middle wrapper
  use :middleware, ValidationMiddleware     # 3rd: innermost wrapper

  def call
    # Core logic executes here
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

## Short-circuiting

> [!WARNING]
> Middleware can halt execution by not calling the next callable. This prevents the task and subsequent middleware from executing.

```ruby
class RateLimitMiddleware < CMDx::Middleware
  def initialize(limit: 100, window: 1.hour)
    @limit = limit
    @window = window
  end

  def call(task, callable)
    key = "rate_limit:#{task.context.current_user&.id}"
    current_count = Rails.cache.read(key) || 0

    if current_count >= @limit
      task.fail!(Rate limit exceeded: #{@limit} requests per hour")
      return task.result  # Short-circuit - task never executes
    end

    Rails.cache.write(key, current_count + 1, expires_in: @window)
    callable.call(task)
  end
end

class SendEmail < CMDx::Task
  use :middleware, RateLimitMiddleware, limit: 50

  def call
    # Only executes if rate limit check passes
    EmailService.deliver(email_params)
  end
end
```

## Inheritance

> [!TIP]
> Middleware is inherited from parent classes, making it ideal for application-wide concerns.

```ruby
class Application < CMDx::Task
  use :middleware, RequestIdMiddleware      # All tasks get request tracking
  use :middleware, PerformanceMiddleware    # All tasks get performance monitoring
  use :middleware, ErrorReportingMiddleware # All tasks get error reporting
end

class ProcessOrder < ApplicationTask
  use :middleware, AuthenticationMiddleware  # Added to inherited middleware
  use :middleware, OrderValidationMiddleware # Domain-specific validation

  def call
    # Inherits all ApplicationTask middleware plus order-specific ones
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

## Built-in Middleware

### Timeout Middleware

Enforces execution time limits with support for static and dynamic timeout values.

#### Basic Usage

```ruby
class ProcessLargeReport < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: 300

  def call
    # Long-running report generation with 5-minute timeout
    ReportGenerator.create(report_params)
  end
end

# Default timeout (3 seconds)
class QuickValidation < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout

  def call
    # Fast validation with default 3-second timeout
    ValidationService.validate(data)
  end
end
```

#### Dynamic Timeout Calculation

> [!NOTE]
> Timeout supports method names, procs, and lambdas for dynamic calculation based on task context.

```ruby
# Method-based timeout
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: :calculate_timeout

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end

  private

  def calculate_timeout
    base_timeout = 30
    base_timeout += (context.order_items.count * 2)  # 2 seconds per item
    base_timeout += 60 if context.payment_method == "bank_transfer"
    base_timeout
  end
end

# Proc-based timeout
class ProcessWorkflow < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: -> {
    context.workflow_size > 100 ? 120 : 60
  }

  def call
    context.workflow_items.each { |item| process_item(item) }
  end
end
```

#### Timeout Precedence

The middleware determines timeout values using this precedence:

1. **Explicit timeout value** (Integer/Float, Symbol, Proc/Lambda)
2. **Default value** of 3 seconds when no timeout resolves

```ruby
# Static timeout - always 45 seconds
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: 45
end

# Method returns nil - falls back to 3 seconds
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: :might_return_nil

  private
  def might_return_nil
    nil  # Uses 3-second default
  end
end
```

#### Conditional Timeout

```ruby
# Environment-based timeout
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout,
      seconds: 60,
      unless: -> { Rails.env.development? }

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end

# Context-based timeout
class SendEmail < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout,
      seconds: 30,
      if: :timeout_enabled?

  private

  def timeout_enabled?
    !context.background_job?
  end
end
```

### Correlate Middleware

> [!NOTE]
> Manages correlation IDs for request tracing across task boundaries, enabling distributed system observability.

```ruby
class ProcessApiRequest < CMDx::Task
  use :middleware, CMDx::Middlewares::Correlate

  def call
    # Correlation ID automatically managed and propagated
    context.api_response = ExternalService.call(request_data)
  end
end
```

#### Correlation Precedence

The middleware determines correlation IDs using this hierarchy:

1. **Explicit correlation ID** (string, proc, method name)
2. **Thread-local correlation** (CMDx::Correlator.id)
3. **Existing chain ID** (inherited from parent task)
4. **Generated UUID** (when none exist)

```ruby
# Explicit correlation ID
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Correlate, id: "order-processing"
end

# Dynamic correlation ID
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Correlate, id: -> { "order-#{order_id}" }
end

# Method-based correlation ID
class ProcessApiRequest < CMDx::Task
  use :middleware, CMDx::Middlewares::Correlate, id: :generate_correlation_id

  private

  def generate_correlation_id
    "api-#{context.request_id}-#{context.user_id}"
  end
end
```

#### Request Tracing Integration

```ruby
class ApiController < ApplicationController
  before_action :set_correlation_id

  def process_order
    result = ProcessOrderTask.call(order_params)

    if result.success?
      render json: { order: result.context.order, correlation_id: result.chain.id }
    else
      render json: { error: result.reason }, status: 422
    end
  end

  private

  def set_correlation_id
    correlation_id = request.headers['X-Correlation-ID'] || request.uuid
    CMDx::Correlator.id = correlation_id
    response.headers['X-Correlation-ID'] = correlation_id
  end
end

class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Correlate

  def call
    # Inherits correlation ID from controller thread context
    ValidateOrderDataTask.call(context)
    ChargePaymentTask.call(context)
    SendConfirmationEmailTask.call(context)
  end
end
```

## Writing Custom Middleware

> [!IMPORTANT]
> Custom middleware must inherit from `CMDx::Middleware` and implement the `call(task, callable)` method.

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

class CacheMiddleware < CMDx::Middleware
  def initialize(ttl: 300, key_prefix: nil)
    @ttl = ttl
    @key_prefix = key_prefix
  end

  def call(task, callable)
    cache_key = build_cache_key(task)
    cached_result = Rails.cache.read(cache_key)

    return cached_result if cached_result

    result = callable.call(task)

    if result.success?
      Rails.cache.write(cache_key, result, expires_in: @ttl)
    end

    result
  end

  private

  def build_cache_key(task)
    base_key = task.class.name.underscore
    param_hash = Digest::MD5.hexdigest(task.context.to_h.to_json)
    [@key_prefix, base_key, param_hash].compact.join(':')
  end
end
```

## Error Handling

> [!WARNING]
> Middleware errors can prevent task execution. Handle exceptions appropriately and consider their impact on the execution chain.

### Common Error Scenarios

```ruby
class ErrorProneMiddleware < CMDx::Middleware
  def call(task, callable)
    # Middleware error prevents task execution
    raise "Configuration missing" unless configured?

    callable.call(task)
  rescue StandardError => e
    # Handle middleware-specific errors
    task.fail!(Middleware error: #{e.message}")
    task.result
  end
end

# Timeout errors are automatically handled
class ProcessOrder < CMDx::Task
  use :middleware, CMDx::Middlewares::Timeout, seconds: 5

  def call
    sleep(10)  # Exceeds timeout
  end
end

result = ProcessOrderTask.call
result.failed?  #=> true
result.reason   #=> "Task timed out after 5 seconds"
```

### Middleware Error Recovery

```ruby
class ResilientMiddleware < CMDx::Middleware
  def call(task, callable)
    callable.call(task)
  rescue ExternalServiceError => e
    # Log error but allow task to complete
    Rails.logger.error "External service unavailable: #{e.message}"

    # Continue execution with degraded functionality
    task.context.external_service_available = false
    callable.call(task)
  end
end
```

> [!TIP]
> Design middleware to fail gracefully when possible. Consider whether middleware failure should prevent task execution or allow degraded operation.

---

- **Prev:** [Callbacks](callbacks.md)
- **Next:** [Workflows](workflows.md)
