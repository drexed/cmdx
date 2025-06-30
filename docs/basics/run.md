# Basics - Run

A run represents a collection of related task executions that share a common execution context. Runs provide unified tracking, indexing, and reporting for task workflows, making it easy to monitor complex business logic and identify all tasks involved in a single operation.

## Table of Contents

- [Automatic Run Creation](#automatic-run-creation)
- [Run Inheritance](#run-inheritance)
- [Run Structure and Metadata](#run-structure-and-metadata)
- [Correlation ID Integration](#correlation-id-integration)
- [State Delegation](#state-delegation)
- [Result Filtering and Statistics](#result-filtering-and-statistics)
- [Serialization and Logging](#serialization-and-logging)
- [Task Indexing](#task-indexing)
- [Run Lifecycle](#run-lifecycle)

## Automatic Run Creation

Every task execution automatically creates or joins a run context:

```ruby
# Single task creates its own run
result = ProcessUserOrderTask.call(order_id: 123)
result.run.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.run.results.size #=> 1
```

## Run Inheritance

When tasks call other tasks using shared context, they automatically inherit the parent's run, creating a cohesive execution trail:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks inherit the ProcessUserOrderTask run_id
    SendOrderConfirmationTask.call(context)
    NotifyWarehousePartnersTask.call(context)
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
run = result.run

# All related tasks share the same run
run.results.size #=> 3
run.results.map(&:task).map(&:class)
#=> [ProcessUserOrderTask, SendOrderConfirmationTask, NotifyWarehousePartnersTask]
```

> [!NOTE]
> When passing context between tasks, subtasks automatically inherit the parent's run_id, creating a unified execution trail for debugging and monitoring purposes.

## Run Structure and Metadata

Runs provide comprehensive execution information:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
run = result.run

# Run identification
run.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
run.results #=> [<CMDx::Result ...>, <CMDx::Result ...>]

# Execution state (delegates to first result)
run.state   #=> "complete"
run.status  #=> "success"
run.outcome #=> "success"
run.runtime #=> 0.5
```

## Correlation ID Integration

Runs automatically integrate with the correlation tracking system, providing seamless request tracing across task boundaries. The run ID serves as the correlation identifier, enabling you to trace execution flows through distributed systems and complex business logic.

### Automatic Correlation Inheritance

Runs inherit correlation IDs using a hierarchical precedence system:

```ruby
# 1. Explicit run ID takes highest precedence
result = ProcessUserOrderTask.call(run: { id: "custom-correlation-123" })
result.run.id #=> "custom-correlation-123"

# 2. Thread-local correlation ID is used if no explicit ID
CMDx::Correlator.id = "thread-correlation-456"
result = ProcessUserOrderTask.call
result.run.id #=> "thread-correlation-456"

# 3. Generated UUID when no correlation exists
CMDx::Correlator.clear
result = ProcessUserOrderTask.call
result.run.id #=> "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated)
```

### Cross-Task Correlation Propagation

When tasks call subtasks with shared context, correlation IDs automatically propagate:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    # Set correlation for this execution context
    CMDx::Correlator.id = "user-order-correlation-123"

    context.order = Order.find(order_id)

    # Subtasks inherit the same correlation ID
    SendOrderConfirmationTask.call(context)
    NotifyWarehousePartnersTask.call(context)
  end
end

result = ProcessUserOrderTask.call(order_id: 456)
run = result.run

# All tasks share the same correlation ID
run.id #=> "user-order-correlation-123"
run.results.all? { |r| r.run.id == "user-order-correlation-123" } #=> true
```

### Correlation Context Management

Use correlation blocks to manage correlation scope:

```ruby
# Correlation applies only within the block
CMDx::Correlator.use("api-request-789") do
  result = ProcessApiRequestTask.call(request_data: data)
  result.run.id #=> "api-request-789"

  # Nested task calls inherit the same correlation
  AuditLogTask.call(result.context)
end

# Outside the block, correlation context is restored
result = AnotherTask.call
result.run.id #=> different correlation ID
```

### Middleware Integration

The `CMDx::Middlewares::Correlate` middleware automatically manages correlation contexts during task execution:

```ruby
class ProcessOrderTask < CMDx::Task
  # Apply correlate middleware globally or per-task
  use CMDx::Middlewares::Correlate

  def call
    # Correlation is automatically managed
    # Run ID reflects the established correlation context
  end
end
```

> [!TIP]
> Run IDs serve as correlation identifiers, making it easy to trace related operations across your application. Use `CMDx::Correlator.use` blocks to establish correlation contexts for groups of related tasks.

> [!NOTE]
> Correlation IDs are particularly useful for debugging distributed systems, API request tracing, and understanding complex business workflows. All logs and results automatically include the run ID for correlation.

## State Delegation

Run state information delegates to the first (primary) result, representing the overall execution outcome:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    ValidateOrderDataTask.call(context)   # Success
    ProcessOrderPaymentTask.call(context) # Failed
  end
end

result = ProcessOrderTask.call
run = result.run

# Run status reflects the main task, not subtasks
run.status            #=> "success" (ProcessOrderTask succeeded)
run.state             #=> "complete"

# Individual task results maintain their own state
run.results[0].status #=> "success" (ProcessOrderTask)
run.results[1].status #=> "success" (ValidateOrderDataTask)
run.results[2].status #=> "failed"  (ProcessOrderPaymentTask)
```

> [!IMPORTANT]
> Run state always reflects the primary (first) task outcome, not the subtasks. Individual subtask results maintain their own success/failure states.

## Result Filtering and Statistics

Runs provide methods for analyzing execution results:

```ruby
result = ProcessLargeOrderTask.call
run = result.run

# Filter results by status
successful_tasks = run.results.select(&:success?)
failed_tasks = run.results.select(&:failed?)
skipped_tasks = run.results.select(&:skipped?)

# Get execution statistics
total_tasks = run.results.size
success_rate = (successful_tasks.size.to_f / total_tasks * 100).round(1)

puts "Executed #{total_tasks} tasks with #{success_rate}% success rate"
puts "Failed tasks: #{failed_tasks.map { |r| r.task.class.name }.join(', ')}"
```

## Serialization and Logging

Runs provide comprehensive serialization capabilities for monitoring and debugging:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
run = result.run

# Hash representation with all execution data
run.to_h
#=> {
#     id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     runtime: 0.5,
#     results: [
#       { class: "ProcessUserOrderTask", state: "complete", status: "success", ... },
#       { class: "SendOrderConfirmationTask", state: "complete", status: "success", ... },
#       { class: "NotifyWarehousePartnersTask", state: "complete", status: "success", ... }
#     ]
#   }

# Human-readable summary
puts run.to_s
#   Task name                     Index   Run ID      Task ID   etc
# -----------------------------------------------------------------
#=> ProcessUserOrderTask          0       foobar123   abc123    ...
#=> SendOrderConfirmationTask     1       foobar123   def456    ...
#=> NotifyWarehousePartnersTask   2       foobar123   ghi789    ...
```

## Task Indexing

Runs automatically track the execution order of related tasks:

```ruby
result = ProcessOrderTask.call
run = result.run

# Get index of specific results
run.index(run.results[0]) #=> 0 (first task)
run.index(run.results[1]) #=> 1 (second task)
run.index(run.results[2]) #=> 2 (third task)

# Index corresponds to execution order
run.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class.name}"
end
# 0: ProcessOrderTask
# 1: ValidateOrderDataTask
# 2: ProcessOrderPaymentTask
```

## Run Lifecycle

Runs follow a predictable lifecycle:

1. **Creation** - New run created for initial task
2. **Inheritance** - Subtasks join existing run via context passing
3. **Population** - Results added as tasks execute
4. **Completion** - Run state reflects overall execution
5. **Freezing** - Run becomes immutable with final state

> [!TIP]
> Use runs for monitoring complex workflows. The automatic inheritance through context passing makes it easy to track all related operations without manual coordination.

---

- **Prev:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
- **Next:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
