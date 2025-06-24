# Basics - Call

Calling a task executes the business logic within it. Tasks provide two execution methods that handle success and failure scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow.

## Execution Methods Overview

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `call` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `call!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` on failure/skip | Exception-based control flow |

## Non-bang Call (`call`)

The `call` method always returns a `CMDx::Result` object regardless of the execution outcome. This is the preferred method for most use cases as it provides consistent error handling without exceptions.

```ruby
result = ProcessOrderTask.call(order_id: 123)

# Check execution state
result.success?     #=> true/false
result.failed?      #=> true/false
result.skipped?     #=> true/false

# Access result data
result.context.order_id #=> 123
result.runtime          #=> 0.05 (seconds)
result.state           #=> "complete"
result.status          #=> "success"
```

### Handling Different Outcomes

```ruby
result = ProcessOrderTask.call(order_id: 123)

case result.status
when "success"
  puts "Order processed: #{result.context.order.id}"
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
  result = ProcessOrderTask.call!(order_id: 123)
  puts "Success: #{result.context.order.id}"
rescue CMDx::Failed => e
  # Handle failure
  retry_job(e.result)
rescue CMDx::Skipped => e
  # Handle skip
  log_skip(e.result)
end
```

### Exception Types

Different task outcomes raise specific exceptions:

- **`CMDx::Failed`** - Raised when task execution fails
- **`CMDx::Skipped`** - Raised when task execution is skipped
- **Other custom exceptions** based on `task_halt` configuration

## Parameter Passing

Both call methods accept parameters that become available in the task context:

```ruby
# Pass parameters directly
result = ProcessOrderTask.call(
  order_id: 123,
  notify_customer: true,
  priority: "high"
)

# Pass existing context
existing_context = CMDx::Context.build(order_id: 123)
result = ProcessOrderTask.call(existing_context)

# Pass result context from another task
previous_result = ValidateOrderTask.call(order_id: 123)
result = ProcessOrderTask.call(previous_result.context)
```

## Direct Instantiation

Tasks can be instantiated directly using the `new` method, providing more flexibility for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = ProcessOrderTask.new(order_id: 123, notify_customer: true)

# Access task properties before execution
task.id                    #=> "abc123..." (unique task ID)
task.context.order_id      #=> 123
task.context.notify_customer #=> true
task.result.state          #=> "initialized"

# Manual execution (advanced use case)
task.perform
task.result.success?       #=> true/false
```

### Direct vs Class Method Execution

| Approach | Use Case | Benefits |
|----------|----------|----------|
| `TaskClass.call(...)` | Standard execution | Simple, consistent, handles all lifecycle |
| `TaskClass.call!(...)` | Exception-based flow | Automatic fault raising |
| `TaskClass.new(...).perform` | Advanced scenarios | Full control, testing, custom patterns |

> [!NOTE]
> Direct instantiation gives you access to the task instance before and after execution, but you're responsible for calling the execution method. Use class methods (`call`/`call!`) for standard use cases.

## Result Propagation (`throw!`)

The `throw!` method enables result propagation, allowing tasks to bubble up failures from subtasks while preserving the original fault information:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    validation_result = ValidateOrderTask.call(context)
    throw!(validation_result) if validation_result.failed?

    payment_result = ProcessPaymentTask.call(context)
    throw!(payment_result) if payment_result.failed?

    # Continue with main logic
    finalize_order
  end
end
```

## Result Callbacks

Results support fluent callback patterns for conditional logic:

```ruby
ProcessOrderTask
  .call(order_id: 123)
  .on_success { |result|
    NotificationService.call(result.context)
  }
  .on_failed { |result|
    ErrorReporter.notify(result.metadata)
  }
  .on_executed { |result|
    MetricsService.record_execution_time(result.runtime)
  }
```

### Available Callbacks

```ruby
result = ProcessOrderTask.call(order_id: 123)

# State-based callbacks
result
  .on_complete { |r| handle_completion(r) }
  .on_interrupted { |r| handle_interruption(r) }
  .on_executed { |r| cleanup_resources(r) }

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
result = ProcessOrderTask.call(order_id: 123)

# Execution states
result.state  #=> "initialized" -> "executing" -> "complete"/"interrupted"

# Outcome statuses
result.status #=> "success"/"failed"/"skipped"
```

## Return Value Details

The `Result` object provides comprehensive execution information:

```ruby
result = ProcessOrderTask.call(order_id: 123)

# Execution metadata
result.id           #=> "abc123..."  (unique task execution ID)
result.runtime      #=> 0.05         (execution time in seconds)
result.task         #=> ProcessOrderTask instance
result.run          #=> Run object for tracking related executions

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata

# State checking methods
result.good?        #=> true for success/skipped
result.bad?         #=> true for failed/skipped
result.complete?    #=> true when execution finished
result.interrupted? #=> true for failed/skipped
```

## Best Practices

### When to Use `call`

- **Application controllers** where you handle results explicitly
- **Services** where consistent return values are important
- **Testing scenarios** where you need to inspect all outcomes
- **Batch processing** where exceptions would interrupt the flow

### When to Use `call!`

- **Background jobs** with retry mechanisms
- **Pipeline operations** where failures should halt execution
- **Scenarios** where exception-based control flow is preferred
- **Workflow orchestration** where failures need immediate attention

### Result Handling

- **Use callbacks** for clean conditional execution
- **Check specific statuses** rather than just success/failure
- **Preserve result context** when chaining tasks
- **Leverage `throw!`** for fault propagation in complex workflows

> [!IMPORTANT]
> Tasks are single-use objects. Once executed, they are frozen and cannot be called again. Create a new task instance (using `call`, `call!`, or `new`) to execute the same task again.

---

- **Prev:** [Basics - Setup](https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md)
- **Next:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
