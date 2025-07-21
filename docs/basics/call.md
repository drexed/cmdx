# Basics - Call

Task execution in CMDx provides two distinct methods that handle success and failure scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow in your application workflows.

## Table of Contents

- [TLDR](#tldr)
- [Execution Methods Overview](#execution-methods-overview)
- [Non-bang Call (`call`)](#non-bang-call-call)
- [Bang Call (`call!`)](#bang-call-call)
- [Direct Instantiation](#direct-instantiation)
- [Parameter Passing](#parameter-passing)
- [Result Propagation (`throw!`)](#result-propagation-throw)
- [Result Callbacks](#result-callbacks)
- [Task State Lifecycle](#task-state-lifecycle)
- [Error Handling](#error-handling)
- [Return Value Details](#return-value-details)

## TLDR

```ruby
# Standard execution (preferred)
result = ProcessOrderTask.call(order_id: 12345)
result.success?  # → true/false

# Exception-based execution
begin
  result = ProcessOrderTask.call!(order_id: 12345)
  # Handle success
rescue CMDx::Failed => e
  # Handle failure
end

# Result callbacks
ProcessOrderTask.call(order_id: 12345)
  .on_success { |result| notify_customer(result) }
  .on_failed { |result| handle_error(result) }

# Propagate failures
throw!(validation_result) if validation_result.failed?
```

## Execution Methods Overview

> [!NOTE]
> Tasks are single-use objects. Once executed, they are frozen and cannot be called again. Create a new instance for subsequent executions.

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `call` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `call!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` on failure/skip | Exception-based control flow |

## Non-bang Call (`call`)

The `call` method always returns a `CMDx::Result` object regardless of execution outcome. This is the preferred method for most use cases.

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Check execution state
result.success?         # → true/false
result.failed?          # → true/false
result.skipped?         # → true/false

# Access result data
result.context.order_id # → 12345
result.runtime          # → 0.05 (seconds)
result.state            # → "complete"
result.status           # → "success"
```

### Handling Different Outcomes

```ruby
result = ProcessOrderTask.call(order_id: 12345)

case result.status
when "success"
  SendConfirmationTask.call(result.context)
when "skipped"
  Rails.logger.info("Order skipped: #{result.metadata[:reason]}")
when "failed"
  RetryOrderJob.perform_later(result.context.order_id)
end
```

## Bang Call (`call!`)

The bang `call!` method raises a `CMDx::Fault` exception when tasks fail or are skipped. It returns a `CMDx::Result` object only on success.

> [!WARNING]
> `call!` behavior depends on the `task_halt` configuration. By default, it raises exceptions for both failures and skips.

```ruby
begin
  result = ProcessOrderTask.call!(order_id: 12345)
  SendConfirmationTask.call(result.context)
rescue CMDx::Failed => e
  RetryOrderJob.perform_later(e.result.context.order_id)
rescue CMDx::Skipped => e
  Rails.logger.info("Order skipped: #{e.result.metadata[:reason]}")
end
```

### Exception Types

| Exception | Raised When | Access Result |
|-----------|-------------|---------------|
| `CMDx::Failed` | Task execution fails | `exception.result` |
| `CMDx::Skipped` | Task execution is skipped | `exception.result` |

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = ProcessOrderTask.new(order_id: 12345, notify_customer: true)

# Access properties before execution
task.id                      # → "abc123..." (unique task ID)
task.context.order_id        # → 12345
task.context.notify_customer # → true
task.result.state            # → "initialized"

# Manual execution
task.process
task.result.success?         # → true/false
```

### Execution Approaches

| Approach | Use Case | Benefits |
|----------|----------|----------|
| `TaskClass.call(...)` | Standard execution | Simple, handles full lifecycle |
| `TaskClass.call!(...)` | Exception-based flow | Automatic fault raising |
| `TaskClass.new(...).process` | Advanced scenarios | Full control, testing flexibility |

## Parameter Passing

All methods accept parameters that become available in the task context:

```ruby
# Direct parameters
result = ProcessOrderTask.call(
  order_id: 12345,
  notify_customer: true,
  priority: "high"
)

# From another task result
validation_result = ValidateOrderTask.call(order_id: 12345)

# Pass Result object directly
result = ProcessOrderTask.call(validation_result)

# Pass context from previous result
result = ProcessOrderTask.call(validation_result.context)
```

## Result Propagation (`throw!`)

The `throw!` method enables result propagation, allowing tasks to bubble up failures from subtasks while preserving the original fault information:

> [!IMPORTANT]
> Use `throw!` to maintain failure context and prevent nested error handling in complex workflows.

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    # Validate order
    validation_result = ValidateOrderTask.call(context)
    throw!(validation_result) if validation_result.failed?

    # Process payment
    payment_result = ProcessPaymentTask.call(context)
    throw!(payment_result) if payment_result.failed?

    # Schedule delivery
    delivery_result = ScheduleDeliveryTask.call(context)
    throw!(delivery_result) unless delivery_result.success?

    # Continue with main logic
    finalize_order_processing
  end
end
```

## Result Callbacks

Results support fluent callback patterns for conditional logic:

```ruby
ProcessOrderTask
  .call(order_id: 12345)
  .on_success { |result|
    SendOrderConfirmationTask.call(result.context)
  }
  .on_failed { |result|
    ErrorReportingService.notify(result.metadata[:error])
  }
  .on_executed { |result|
    MetricsService.timing('order.processing_time', result.runtime)
  }
```

### Available Callbacks

> [!TIP]
> Callbacks return the result object, enabling method chaining for complex conditional logic.

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# State-based callbacks
result
  .on_complete { |r| cleanup_resources(r) }
  .on_interrupted { |r| handle_interruption(r) }
  .on_executed { |r| log_execution_time(r) }

# Status-based callbacks
result
  .on_success { |r| handle_success(r) }
  .on_skipped { |r| handle_skip(r) }
  .on_failed { |r| handle_failure(r) }

# Outcome-based callbacks
result
  .on_good { |r| log_positive_outcome(r) }    # success or skipped
  .on_bad { |r| log_negative_outcome(r) }     # failed only
```

## Task State Lifecycle

Tasks progress through defined states during execution:

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Execution states
result.state # → "initialized" → "executing" → "complete"/"interrupted"

# Outcome statuses
result.status # → "success"/"failed"/"skipped"
```

## Error Handling

### Common Error Scenarios

```ruby
# Parameter validation failure
result = ProcessOrderTask.call(order_id: nil)
result.failed?                    # → true
result.metadata[:reason]          # → "order_id is required"

# Business logic failure
result = ProcessOrderTask.call(order_id: 99999)
result.failed?                    # → true
result.metadata[:error].class     # → ActiveRecord::RecordNotFound

# Task skipped due to conditions
result = ProcessOrderTask.call(order_id: 12345, force: false)
result.skipped?                   # → true (if order already processed)
result.metadata[:reason]          # → "Order already processed"
```

### Exception Handling with `call!`

```ruby
begin
  result = ProcessOrderTask.call!(order_id: 12345)
rescue CMDx::Failed => e
  # Access original error details
  error_type = e.result.metadata[:error].class
  error_message = e.result.metadata[:reason]

  case error_type
  when ActiveRecord::RecordNotFound
    render json: { error: "Order not found" }, status: 404
  when PaymentError
    render json: { error: "Payment failed" }, status: 402
  else
    render json: { error: "Processing failed" }, status: 500
  end
end
```

## Return Value Details

The `Result` object provides comprehensive execution information:

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Execution metadata
result.id           # → "abc123..."  (unique execution ID)
result.runtime      # → 0.05         (execution time in seconds)
result.task         # → ProcessOrderTask instance
result.chain        # → Chain object for tracking executions

# Context and metadata
result.context      # → Context with all task data
result.metadata     # → Hash with execution metadata

# State checking methods
result.good?        # → true for success/skipped
result.bad?         # → true for failed only
result.complete?    # → true when execution finished normally
result.interrupted? # → true for failed/skipped
result.executed?    # → true for any completed execution
```

---

- **Prev:** [Basics - Setup](setup.md)
- **Next:** [Basics - Context](context.md)
