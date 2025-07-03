# Basics - Call

Calling a task executes the business logic within it. Tasks provide two execution methods that handle success and failure scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow.

## Table of Contents

- [Execution Methods Overview](#execution-methods-overview)
- [Non-bang Call (`call`)](#non-bang-call-call)
- [Bang Call (`call!`)](#bang-call-call)
- [Parameter Passing](#parameter-passing)
- [Direct Instantiation](#direct-instantiation)
- [Result Propagation (`throw!`)](#result-propagation-throw)
- [Result Callbacks](#result-callbacks)
- [Task State Lifecycle](#task-state-lifecycle)
- [Return Value Details](#return-value-details)

## Execution Methods Overview

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `call` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `call!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` on failure/skip | Exception-based control flow |

## Non-bang Call (`call`)

The `call` method always returns a `CMDx::Result` object regardless of execution outcome. This is the preferred method for most use cases.

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Check execution state
result.success?         #=> true/false
result.failed?          #=> true/false
result.skipped?         #=> true/false

# Access result data
result.context.order_id #=> 12345
result.runtime          #=> 0.05 (seconds)
result.state            #=> "complete"
result.status           #=> "success"
```

### Handling Different Outcomes

```ruby
result = ProcessOrderTask.call(order_id: 12345)

case result.status
when "success"
  puts "Order processed: #{result.context.order_id}"
when "skipped"
  puts "Order skipped: #{result.metadata[:reason]}"
when "failed"
  puts "Order failed: #{result.metadata[:reason]}"
end
```

## Bang Call (`call!`)

The bang `call!` method raises a `CMDx::Fault` exception when tasks fail or are skipped, based on the `task_halt` configuration. It returns a `CMDx::Result` object only on success. This method is useful in scenarios where you want exception-based control flow.

```ruby
begin
  result = ProcessOrderTask.call!(order_id: 12345)
  puts "Order processed: #{result.context.order_id}"
rescue CMDx::Failed => e
  # Handle failure
  RetryOrderJob.perform_later(e.result.context.order_id)
rescue CMDx::Skipped => e
  # Handle skip
  Rails.logger.info("Order skipped: #{e.result.metadata[:reason]}")
end
```

### Exception Types

| Exception | Raised When | Purpose |
|-----------|-------------|---------|
| `CMDx::Failed` | Task execution fails | Handle failure scenarios |
| `CMDx::Skipped` | Task execution is skipped | Handle skip scenarios |

## Parameter Passing

Both methods accept parameters that become available in the task context:

```ruby
# Direct parameters
result = ProcessOrderTask.call(
  order_id: 12345,
  notify_customer: true,
  priority: "high"
)

# From another task result
validation_result = ValidateOrderTask.call(order_id: 12345)
result = ProcessOrderTask.call(validation_result.context)
```

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = ProcessOrderTask.new(order_id: 12345, notify_customer: true)

# Access properties before execution
task.id                      #=> "abc123..." (unique task ID)
task.context.order_id        #=> 12345
task.context.notify_customer #=> true
task.result.state            #=> "initialized"

# Manual execution
task.perform
task.result.success?         #=> true/false
```

### Execution Approaches

| Approach | Use Case | Benefits |
|----------|----------|----------|
| `TaskClass.call(...)` | Standard execution | Simple, handles full lifecycle |
| `TaskClass.call!(...)` | Exception-based flow | Automatic fault raising |
| `TaskClass.new(...).perform` | Advanced scenarios | Full control, testing flexibility |

> [!NOTE]
> Direct instantiation gives you access to the task instance before and after execution, but you must call the execution method manually.

## Result Propagation (`throw!`)

The `throw!` method enables result propagation, allowing tasks to bubble up failures from subtasks while preserving the original fault information:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    validation_result = ValidateOrderTask.call(context)
    throw!(validation_result) if validation_result.failed?

    payment_result = ProcessPaymentTask.call(context)
    throw!(payment_result) if payment_result.skipped?

    delivery_result = ScheduleDeliveryTask.call(context)
    throw!(delivery_result) # failed or skipped

    # Continue with main logic
    context.order = Order.find(context.order_id)
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
    Honeybadger.notify(result.metadata[:error])
  }
  .on_executed { |result|
    StatsD.timing('order.processing_time', result.runtime)
  }
```

### Available Callbacks

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
  .on_good { |r| log_positive_outcome(r) }
  .on_bad { |r| log_negative_outcome(r) }
```

## Task State Lifecycle

Tasks progress through defined states during execution:

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Execution states
result.state #=> "initialized" -> "executing" -> "complete"/"interrupted"

# Outcome statuses
result.status #=> "success"/"failed"/"skipped"
```

## Return Value Details

The `Result` object provides comprehensive execution information:

```ruby
result = ProcessOrderTask.call(order_id: 12345)

# Execution metadata
result.id           #=> "abc123..."  (unique execution ID)
result.runtime      #=> 0.05         (execution time in seconds)
result.task         #=> ProcessOrderTask instance
result.chain        #=> Chain object for tracking executions

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata

# State checking methods
result.good?        #=> true for success/skipped
result.bad?         #=> true for failed/skipped
result.complete?    #=> true when execution finished
result.interrupted? #=> true for failed/skipped
```

> [!IMPORTANT]
> Tasks are single-use objects. Once executed, they are frozen and cannot be called again. Create a new task instance to execute the same task again.

---

- **Prev:** [Basics - Setup](setup.md)
- **Next:** [Basics - Context](context.md)
