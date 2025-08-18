# Basics - Execution

Task execution in CMDx provides two distinct methods that handle success and halt scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow in your application workflows.

## Table of Contents

- [Methods Overview](#methods-overview)
- [Non-bang Execution](#non-bang-execution)
- [Bang Execution](#bang-execution)
- [Direct Instantiation](#direct-instantiation)
- [Result Handlers](#result-handlers)
  - [Available Handlers](#available-handlers)
- [Execution Lifecycle](#execution-lifecycle)
- [Result Details](#result-details)

## Methods Overview

Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.
Create a new instance for subsequent executions.

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `execute` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `execute!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` when skipped or failed | Exception-based control flow |

## Non-bang Execution

The `execute` method always returns a `CMDx::Result` object regardless of execution outcome.
This is the preferred method for most use cases.

```ruby
result = ProcessOrder.execute(order_id: 12345)

# Check execution state
result.success?         #=> true/false
result.failed?          #=> true/false
result.skipped?         #=> true/false

# Access result data
result.context.order_id #=> 12345
result.state            #=> "complete"
result.status           #=> "success"
```

## Bang Execution

The bang `execute!` method raises a `CMDx::Fault` based exception when tasks fail or are skipped,
 and returns a `CMDx::Result` object only on success.

| Exception | Raised When |
|-----------|-------------|
| `CMDx::FailFault` | Task execution fails |
| `CMDx::SkipFault` | Task execution is skipped |

> [!WARNING]
> `execute!` behavior depends on the `task_breakpoints` or `workflow_breakpoints` configuration.
> By default, it raises exceptions only on failures.

```ruby
begin
  result = ProcessOrder.execute!(order_id: 12345)
  SendConfirmation.execute(result.context)
rescue CMDx::FailFault => e
  RetryOrderJob.perform_later(e.result.context.order_id)
rescue CMDx::SkipFault => e
  Rails.logger.info("Order skipped: #{e.result.reason}")
end
```

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = ProcessOrder.new(order_id: 12345, notify_customer: true)

# Access properties before execution
task.id                      #=> "abc123..." (unique task ID)
task.context.order_id        #=> 12345
task.context.notify_customer #=> true
task.result.state            #=> "initialized"
task.result.status           #=> "success"

# Manual execution
task.execute
# or
task.execute!

task.result.success?         #=> true/false
```

## Result Handlers

Results support fluent handler patterns for terse conditional logic:

```ruby
ProcessOrder
  .execute(order_id: 12345)
  .on_success { |result| SendOrderConfirmation.execute(result.context) }
  .on_failed { |result| ErrorReportingService.notify(result.cause) }
  .on_executed { |result| MetricsService.timing('order.processing_time', result.metadata[:runtime]) }
```

### Available Handlers

Handlers return the result object, enabling method chaining for complex conditional logic.

```ruby
result = ProcessOrder.execute(order_id: 12345)

# State-based handlers
result
  .on_complete { |r| cleanup_resources(r) }
  .on_interrupted { |r| handle_interruption(r) }
  .on_executed { |r| log_execution_time(r) }

# Status-based handlers
result
  .on_success { |r| handle_success(r) }
  .on_skipped { |r| handle_skip(r) }
  .on_failed { |r| handle_failure(r) }

# Outcome-based handlers
result
  .on_good { |r| log_positive_outcome(r) } # success or skipped
  .on_bad { |r| log_negative_outcome(r) }  # skipped or failed
```

## Execution Lifecycle

Tasks progress through defined states and statuses during execution:

```ruby
result = ProcessOrderTask.execute(order_id: 12345)

# Execution states
result.state #=> "initialized" → "executing" → "complete"/"interrupted"

# Outcome statuses
result.status #=> "success"/"failed"/"skipped"
```

## Result Details

The `Result` object provides comprehensive execution information:

```ruby
result = ProcessOrderTask.execute(order_id: 12345)

# Execution metadata
result.id           #=> "abc123..."  (unique execution ID)
result.task         #=> ProcessOrderTask instance (frozen)
result.chain        #=> Task execution chain

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata
```

---

- **Prev:** [Basics - Setup](setup.md)
- **Next:** [Basics - Context](context.md)
