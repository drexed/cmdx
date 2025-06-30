# Basics - Chain

A chain represents a collection of related task executions that share a common execution context. Chains provide unified tracking, indexing, and reporting for task workflows, making it easy to monitor complex business logic and identify all tasks involved in a single operation.

## Table of Contents

- [Automatic Chain Creation](#automatic-chain-creation)
- [Chain Inheritance](#chain-inheritance)
- [Chain Structure and Metadata](#chain-structure-and-metadata)
- [Correlation ID Integration](#correlation-id-integration)
- [State Delegation](#state-delegation)
- [Result Filtering and Statistics](#result-filtering-and-statistics)
- [Serialization and Logging](#serialization-and-logging)
- [Task Indexing](#task-indexing)
- [Chain Lifecycle](#chain-lifecycle)

## Automatic Chain Creation

Every task execution automatically creates or joins a chain context:

```ruby
# Single task creates its own chain
result = ProcessUserOrderTask.call(order_id: 123)
result.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.chain.results.size #=> 1
```

## Chain Inheritance

When tasks call other tasks using shared context, they automatically inherit the parent's chain, creating a cohesive execution trail:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks inherit the ProcessUserOrderTask chain_id
    SendOrderConfirmationTask.call(context)
    NotifyWarehousePartnersTask.call(context)
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
chain = result.chain

# All related tasks share the same chain
chain.results.size #=> 3
chain.results.map(&:task).map(&:class)
#=> [ProcessUserOrderTask, SendOrderConfirmationTask, NotifyWarehousePartnersTask]
```

> [!NOTE]
> When passing context between tasks, subtasks automatically inherit the parent's chain_id, creating a unified execution trail for debugging and monitoring purposes.

## Chain Structure and Metadata

Chains provide comprehensive execution information:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
chain = result.chain

# Chain identification
chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results #=> [<CMDx::Result ...>, <CMDx::Result ...>]

# Execution state (delegates to first result)
chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"
chain.runtime #=> 0.5
```

## Correlation ID Integration

Chains automatically integrate with the correlation tracking system, providing seamless request tracing across task boundaries. The chain ID serves as the correlation identifier, enabling you to trace execution flows through distributed systems and complex business logic.

### Automatic Correlation Inheritance

Chains inherit correlation IDs using a hierarchical precedence system:

```ruby
# 1. Explicit chain ID takes highest precedence
result = ProcessUserOrderTask.call(chain: { id: "custom-correlation-123" })
result.chain.id #=> "custom-correlation-123"

# 2. Thread-local correlation ID is used if no explicit ID
CMDx::Correlator.id = "thread-correlation-456"
result = ProcessUserOrderTask.call
result.chain.id #=> "thread-correlation-456"

# 3. Generated UUID when no correlation exists
CMDx::Correlator.clear
result = ProcessUserOrderTask.call
result.chain.id #=> "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated)
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
chain = result.chain

# All tasks share the same correlation ID
chain.id #=> "user-order-correlation-123"
chain.results.all? { |r| r.chain.id == "user-order-correlation-123" } #=> true
```

### Correlation Context Management

Use correlation blocks to manage correlation scope:

```ruby
# Correlation applies only within the block
CMDx::Correlator.use("api-request-789") do
  result = ProcessApiRequestTask.call(request_data: data)
  result.chain.id #=> "api-request-789"

  # Nested task calls inherit the same correlation
  AuditLogTask.call(result.context)
end

# Outside the block, correlation context is restored
result = AnotherTask.call
result.chain.id #=> different correlation ID
```

### Middleware Integration

The `CMDx::Middlewares::Correlate` middleware automatically manages correlation contexts during task execution:

```ruby
class ProcessOrderTask < CMDx::Task
  # Apply correlate middleware globally or per-task
  use CMDx::Middlewares::Correlate

  def call
    # Correlation is automatically managed
    # Chain ID reflects the established correlation context
  end
end
```

> [!TIP]
> Chain IDs serve as correlation identifiers, making it easy to trace related operations across your application. Use `CMDx::Correlator.use` blocks to establish correlation contexts for groups of related tasks.

> [!NOTE]
> Correlation IDs are particularly useful for debugging distributed systems, API request tracing, and understanding complex business workflows. All logs and results automatically include the chain ID for correlation.

## State Delegation

Chain state information delegates to the first (primary) result, representing the overall execution outcome:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    ValidateOrderDataTask.call(context)   # Success
    ProcessOrderPaymentTask.call(context) # Failed
  end
end

result = ProcessOrderTask.call
chain = result.chain

# Chain status reflects the main task, not subtasks
chain.status            #=> "success" (ProcessOrderTask succeeded)
chain.state             #=> "complete"

# Individual task results maintain their own state
chain.results[0].status #=> "success" (ProcessOrderTask)
chain.results[1].status #=> "success" (ValidateOrderDataTask)
chain.results[2].status #=> "failed"  (ProcessOrderPaymentTask)
```

> [!IMPORTANT]
> Chain state always reflects the primary (first) task outcome, not the subtasks. Individual subtask results maintain their own success/failure states.

## Result Filtering and Statistics

Chains provide methods for analyzing execution results:

```ruby
result = ProcessLargeOrderTask.call
chain = result.chain

# Filter results by status
successful_tasks = chain.results.select(&:success?)
failed_tasks = chain.results.select(&:failed?)
skipped_tasks = chain.results.select(&:skipped?)

# Get execution statistics
total_tasks = chain.results.size
success_rate = (successful_tasks.size.to_f / total_tasks * 100).round(1)

puts "Executed #{total_tasks} tasks with #{success_rate}% success rate"
puts "Failed tasks: #{failed_tasks.map { |r| r.task.class.name }.join(', ')}"
```

## Serialization and Logging

Chains provide comprehensive serialization capabilities for monitoring and debugging:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
chain = result.chain

# Hash representation with all execution data
chain.to_h
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
puts chain.to_s
#   Task name                     Index   Chain ID      Task ID   etc
# -----------------------------------------------------------------
#=> ProcessUserOrderTask          0       foobar123   abc123    ...
#=> SendOrderConfirmationTask     1       foobar123   def456    ...
#=> NotifyWarehousePartnersTask   2       foobar123   ghi789    ...
```

## Task Indexing

Chains automatically track the execution order of related tasks:

```ruby
result = ProcessOrderTask.call
chain = result.chain

# Get index of specific results
chain.index(chain.results[0]) #=> 0 (first task)
chain.index(chain.results[1]) #=> 1 (second task)
chain.index(chain.results[2]) #=> 2 (third task)

# Index corresponds to execution order
chain.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class.name}"
end
# 0: ProcessOrderTask
# 1: ValidateOrderDataTask
# 2: ProcessOrderPaymentTask
```

## Chain Lifecycle

Chains follow a predictable lifecycle:

1. **Creation** - New chain created for initial task
2. **Inheritance** - Subtasks join existing chain via context passing
3. **Population** - Results added as tasks execute
4. **Completion** - Chain state reflects overall execution
5. **Freezing** - Chain becomes immutable with final state

> [!TIP]
> Use chains for monitoring complex workflows. The automatic inheritance through context passing makes it easy to track all related operations without manual coordination.

---

- **Prev:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
- **Next:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
