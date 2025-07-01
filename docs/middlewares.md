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
  - [Correlate Middleware](#correlate-middleware)
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
    start_time = Time.now
    result = callable.call(task)
    duration = Time.now - start_time

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

Enforces execution time limits with support for static and dynamic timeout values.

#### Basic Usage

```ruby
class ProcessLargeReportTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: 300 # 5 minutes

  def call
    # Long-running report generation
  end
end

# Default timeout (3 seconds when no value specified)
class QuickValidationTask < CMDx::Task
  use CMDx::Middlewares::Timeout # Uses 3 seconds default

  def call
    # Fast validation logic
  end
end
```

#### Dynamic Timeout Generation

The middleware supports dynamic timeout calculation using method names, procs, and lambdas:

```ruby
# Method-based timeout calculation
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: :calculate_timeout

  def call
    # Task execution with dynamic timeout
    context.order = Order.find(order_id)
    context.order.process!
  end

  private

  def calculate_timeout
    # Dynamic timeout based on order complexity
    base_timeout = 30
    base_timeout += (context.order_items.count * 2) # 2 seconds per item
    base_timeout += 60 if context.payment_method == "bank_transfer" # Extra time for bank transfers
    base_timeout
  end
end

# Proc-based timeout for inline calculation
class ProcessBatchTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: -> {
    context.batch_size > 100 ? 120 : 60
  }

  def call
    # Processes batch with timeout based on size
    context.batch_items.each { |item| process_item(item) }
  end
end

# Context-aware timeout calculation
class GenerateReportTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: :report_timeout

  def call
    context.report = ReportGenerator.create(report_params)
  end

  private

  def report_timeout
    case context.report_type
    when "summary" then 30
    when "detailed" then 120
    when "comprehensive" then 300
    else 60
    end
  end
end
```

#### Timeout Precedence

The middleware follows this precedence for determining timeout values:

1. **Explicit timeout value** (provided during middleware initialization)
   - Integer/Float: Used as-is for static timeout
   - Symbol: Called as method on task if it exists
   - Proc/Lambda: Executed in task context for dynamic calculation
2. **Default value** of 3 seconds if no timeout is specified or resolved value is nil

```ruby
# Static timeout - highest precedence when specified
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: 45 # Always 45 seconds
end

# Method-based timeout - calls task method
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: :dynamic_timeout

  private
  def dynamic_timeout
    context.priority == "high" ? 120 : 60
  end
end

# Default fallback when method returns nil
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: :might_return_nil

  private
  def might_return_nil
    nil # Falls back to 3 seconds default
  end
end
```

#### Conditional Timeout

Apply timeout middleware conditionally based on environment or task state:

```ruby
# Environment-based conditional timeout
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout,
      seconds: 60,
      unless: -> { Rails.env.development? }

  def call
    # No timeout in development, 60 seconds in other environments
    context.order = Order.find(order_id)
    context.order.process!
  end
end

# Context-based conditional timeout
class SendEmailTask < CMDx::Task
  use CMDx::Middlewares::Timeout,
      seconds: 30,
      if: :timeout_enabled?

  def call
    EmailService.deliver(email_params)
  end

  private

  def timeout_enabled?
    !context.background_job?
  end
end

# Combined dynamic timeout with conditions
class ProcessComplexOrderTask < CMDx::Task
  use CMDx::Middlewares::Timeout,
      seconds: :calculate_timeout,
      unless: :skip_timeout?

  def call
    # Complex order processing
    ValidateOrderTask.call(context)
    ProcessPaymentTask.call(context)
    UpdateInventoryTask.call(context)
  end

  private

  def calculate_timeout
    context.order_complexity == "high" ? 180 : 90
  end

  def skip_timeout?
    Rails.env.test? || context.disable_timeouts?
  end
end
```

#### Global Timeout Configuration

Apply timeout middleware globally with inheritance:

```ruby
class ApplicationTask < CMDx::Task
  use CMDx::Middlewares::Timeout, seconds: 60 # Default 60 seconds for all tasks
end

class QuickTask < ApplicationTask
  use CMDx::Middlewares::Timeout, seconds: 15 # Override with 15 seconds

  def call
    # Fast operation with shorter timeout
  end
end

class LongRunningTask < ApplicationTask
  use CMDx::Middlewares::Timeout, seconds: :dynamic_timeout

  def call
    # Long operation with dynamic timeout
  end

  private

  def dynamic_timeout
    context.data_size > 1000 ? 300 : 120
  end
end
```

> [!WARNING]
> Tasks that exceed their timeout will be interrupted with a `CMDx::TimeoutError` and automatically marked as failed.

> [!TIP]
> Use dynamic timeout calculation to adjust execution limits based on actual task complexity, data size, or business requirements. This provides better resource utilization while maintaining appropriate safety limits.

### Correlate Middleware

Manages correlation IDs for request tracing across task boundaries. This middleware automatically establishes correlation contexts during task execution, enabling you to trace related operations through distributed systems and complex business workflows.

```ruby
class ProcessApiRequestTask < CMDx::Task
  use CMDx::Middlewares::Correlate

  def call
    # Correlation ID is automatically managed
    # Chain ID reflects the established correlation context
    context.api_response = ExternalService.call(request_data)
  end
end
```

#### Correlation Precedence

The middleware follows a hierarchical precedence system for determining correlation IDs:

```ruby
# 1. Explicit correlation ID takes highest precedence

# 1a. Static string ID
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: "fixed-correlation-123"
end
ProcessOrderTask.call # Always uses "fixed-correlation-123"

# 1b. Dynamic proc/lambda ID
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: -> { "order-#{order_id}-#{rand(1000)}" }
end
ProcessOrderTask.call(order_id: 456) # Uses "order-456-847" (random number varies)

# 1c. Method-based ID
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: :correlation_method

  private

  def correlation_method
    "custom-#{order_id}"
  end
end
ProcessOrderTask.call(order_id: 789) # Uses "custom-789"

# 2. Thread-local correlation when no explicit ID
CMDx::Correlator.id = "api-request-456"
ProcessApiRequestTask.call # Uses "api-request-456"

# 3. Existing chain ID when no explicit or thread correlation
task_with_run = ProcessOrderTask.call(chain: { id: "order-chain-789" })
# Uses "order-chain-789"

# 4. Generated UUID when none of the above exist
CMDx::Correlator.clear
ProcessOrderTask.call # Uses generated UUID
```

#### Explicit Correlation IDs

Set fixed or dynamic correlation IDs for specific tasks or workflows using strings, method names, or procs:

```ruby
# Static string correlation ID
class ProcessPaymentTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: "payment-processing"

  def call
    # Always uses "payment-processing" as correlation ID
    # Useful for grouping all payment operations
    context.payment = PaymentService.charge(payment_params)
  end
end

# Dynamic correlation ID using proc/lambda
class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: -> { "order-#{order_id}-#{Time.now.to_i}" }

  def call
    # Dynamic correlation ID based on order and timestamp
    # Each execution gets a unique correlation ID
    ValidateOrderTask.call(context)
    ProcessPaymentTask.call(context)
  end
end

# Method-based correlation ID
class ProcessApiRequestTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: :generate_correlation_id

  def call
    # Uses correlation ID from generate_correlation_id method
    context.api_response = ExternalService.call(request_data)
  end

  private

  def generate_correlation_id
    "api-#{context.request_id}-#{context.user_id}"
  end
end

# Symbol fallback when method doesn't exist
class ProcessBatchTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: :batch_processing

  def call
    # Uses :batch_processing as correlation ID (symbol as-is)
    # since task doesn't respond to batch_processing method
    context.batch_results = process_batch_items
  end
end
```

#### Conditional Correlation

Apply correlation middleware conditionally based on environment or task state:

```ruby
class ProcessOrderTask < CMDx::Task
  # Only apply correlation in production environments
  use CMDx::Middlewares::Correlate, unless: -> { Rails.env.development? }

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end
end

class SendEmailTask < CMDx::Task
  # Apply correlation only when tracing is enabled
  use CMDx::Middlewares::Correlate, if: :tracing_enabled?

  def call
    EmailService.deliver(email_params)
  end

  private

  def tracing_enabled?
    context.enable_tracing == true
  end
end
```

#### Scoped Correlation Context

Use correlation blocks to establish correlation contexts for groups of related tasks:

```ruby
class ProcessOrderWorkflowTask < CMDx::Task
  use CMDx::Middlewares::Correlate

  def call
    # Establish correlation context for entire workflow
    CMDx::Correlator.use("order-workflow-#{order_id}") do
      ValidateOrderTask.call(context)
      ProcessPaymentTask.call(context)
      SendConfirmationTask.call(context)
      UpdateInventoryTask.call(context)
    end
  end
end
```

#### Global Correlation Setup

Apply correlation middleware globally to all tasks:

```ruby
class ApplicationTask < CMDx::Task
  use CMDx::Middlewares::Correlate # All tasks get correlation management
end

class ProcessOrderTask < ApplicationTask
  def call
    # Automatically inherits correlation management
    context.order = Order.find(order_id)
    context.order.process!
  end
end
```

#### Request Tracing Integration

Combine with request identifiers for comprehensive tracing:

```ruby
class ApiController < ApplicationController
  before_action :set_correlation_id

  def process_order
    # Option 1: Use thread-local correlation (inherited by all tasks)
    result = ProcessOrderTask.call(order_params)

    # Option 2: Use explicit correlation ID for this specific request
    # result = ProcessOrderTask.call(order_params.merge(correlation_id: @correlation_id))

    if result.success?
      render json: { order: result.context.order, correlation_id: result.chain.id }
    else
      render json: { error: result.reason }, status: 422
    end
  end

  private

  def set_correlation_id
    @correlation_id = request.headers['X-Correlation-ID'] || SecureRandom.uuid
    CMDx::Correlator.id = @correlation_id
    response.headers['X-Correlation-ID'] = @correlation_id
  end
end

class ProcessOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate

  def call
    # Inherits correlation ID from controller thread context
    # All subtasks will share the same correlation ID
    ValidateOrderDataTask.call(context)
    ChargePaymentTask.call(context)
    SendConfirmationEmailTask.call(context)
  end
end

# Alternative: Task-specific correlation for API endpoints
class ProcessApiOrderTask < CMDx::Task
  use CMDx::Middlewares::Correlate, id: -> { "api-order-#{context.request_id}" }

  def call
    # Uses correlation ID specific to this API request
    # Overrides any thread-local correlation
    ValidateOrderDataTask.call(context)
    ChargePaymentTask.call(context)
    SendConfirmationEmailTask.call(context)
  end
end
```

> [!TIP]
> The Correlate middleware integrates seamlessly with the CMDx logging system. All task execution logs automatically include the correlation ID, making it easy to trace related operations across your application.

> [!NOTE]
> Correlation IDs are thread-safe and automatically propagate through task hierarchies when using shared context. This makes the middleware ideal for distributed tracing and debugging complex business workflows.

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
