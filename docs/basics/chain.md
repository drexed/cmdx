# Basics - Chain

A chain represents a collection of related task executions that share a common execution context. Chains provide unified tracking, indexing, and reporting for task workflows using thread-local storage to automatically group related tasks without manual coordination.

## Table of Contents

- [Thread-Local Chain Management](#thread-local-chain-management)
- [Automatic Chain Creation](#automatic-chain-creation)
- [Chain Inheritance](#chain-inheritance)
- [Chain Structure and Metadata](#chain-structure-and-metadata)
- [Correlation ID Integration](#correlation-id-integration)
- [State Delegation](#state-delegation)
- [Serialization and Logging](#serialization-and-logging)

## Thread-Local Chain Management

Chains use thread-local storage to automatically group related task executions within the same thread while maintaining isolation across different threads:

```ruby
# Each thread gets its own chain context
Thread.new do
  result = ProcessOrderTask.call(order_id: 123)
  result.chain.id    # => unique ID for this thread
end

Thread.new do
  result = ProcessOrderTask.call(order_id: 456)
  result.chain.id    # => different unique ID
end

# Access the current thread's chain
CMDx::Chain.current  # => current chain or nil
CMDx::Chain.clear    # => clears current thread's chain
```

## Automatic Chain Creation

Every task execution automatically creates or joins a thread-local chain context:

```ruby
# Single task creates its own chain
result = ProcessUserOrderTask.call(order_id: 123)
result.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.chain.results.size #=> 1

# Subsequent tasks in the same thread join the existing chain
result2 = AnotherTask.call(data: "test")
result2.chain.id == result.chain.id  #=> true
result2.chain.results.size           #=> 2
```

## Chain Inheritance

When tasks call other tasks within the same thread, they automatically inherit the current chain, creating a cohesive execution trail:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks automatically inherit the current thread's chain
    SendOrderConfirmationTask.call(order_id: order_id)
    NotifyWarehousePartnersTask.call(order_id: order_id)
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
chain = result.chain

# All related tasks share the same chain automatically
chain.results.size #=> 3
chain.results.map(&:task).map(&:class)
#=> [ProcessUserOrderTask, SendOrderConfirmationTask, NotifyWarehousePartnersTask]
```

> [!NOTE]
> Tasks automatically inherit the current thread's chain, creating a unified execution trail for debugging and monitoring purposes without any manual chain management.

## Chain Structure and Metadata

Chains provide comprehensive execution information:

```ruby
result = ProcessUserOrderTask.call(order_id: 123)
chain = result.chain

# Chain identification
chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results #=> [<CMDx::Result ...>, <CMDx::Result ...>]

# Execution state (delegates to outer most result)
chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"
chain.runtime #=> 0.5
```

## Correlation ID Integration

Chains automatically integrate with the correlation tracking system through thread-local storage, providing seamless request tracing across task boundaries. The chain ID serves as the correlation identifier, enabling you to trace execution flows through distributed systems and complex business logic.

### Custom Chain IDs

You can specify custom chain IDs for specific correlation contexts:

```ruby
# Create a chain with custom ID
chain = CMDx::Chain.new(id: "user-session-123")
CMDx::Chain.current = chain

result = ProcessUserOrderTask.call(order_id: 123)
result.chain.id #=> "user-session-123"
```

### Automatic Correlation Inheritance

Chains inherit correlation IDs using a hierarchical precedence system:

```ruby
# 1. Existing chain ID takes precedence
CMDx::Chain.current = CMDx::Chain.new(id: "custom-correlation-123")
result = ProcessUserOrderTask.call(order_id: 123)
result.chain.id #=> "custom-correlation-123"

# 2. Thread-local correlation ID is used if no chain exists
CMDx::Chain.clear
CMDx::Correlator.id = "thread-correlation-456"
result = ProcessUserOrderTask.call
result.chain.id #=> "thread-correlation-456"

# 3. Generated UUID when no correlation exists
CMDx::Correlator.clear
result = ProcessUserOrderTask.call
result.chain.id #=> "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated)
```

### Cross-Task Correlation Propagation

When tasks call subtasks within the same thread, correlation IDs automatically propagate:

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks inherit the same correlation ID automatically
    SendOrderConfirmationTask.call(order_id: order_id)
    NotifyWarehousePartnersTask.call(order_id: order_id)
  end
end

# Set correlation for this execution context
CMDx::Chain.current = CMDx::Chain.new(id: "user-order-correlation-123")

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
  AuditLogTask.call(audit_data: data)
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
> Chain IDs serve as correlation identifiers, making it easy to trace related operations across your application. The thread-local storage ensures automatic correlation without manual chain management.

> [!NOTE]
> Correlation IDs are particularly useful for debugging distributed systems, API request tracing, and understanding complex business workflows. All logs and results automatically include the chain ID for correlation.

## State Delegation

Chain state information delegates to the first (outer most) result, representing the overall execution outcome:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    ValidateOrderDataTask.call!(order_id: order_id)   # Success
    ProcessOrderPaymentTask.call!(order_id: order_id) # Failed
  end
end

result = ProcessOrderTask.call
chain = result.chain

# Chain status reflects the main task, not subtasks
chain.status            #=> "failed" (ProcessOrderPaymentTask failed)
chain.state             #=> "interrupted"

# Individual task results maintain their own state
chain.results[0].status #=> "failed"  (ProcessOrderTask)
chain.results[1].status #=> "success" (ValidateOrderDataTask)
chain.results[2].status #=> "failed"  (ProcessOrderPaymentTask)
```

> [!IMPORTANT]
> Chain state always reflects the first (outer most) task outcome, not the subtasks. Individual subtask results maintain their own success/failure states.

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
#   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
#   ================================================
#
#   ProcessUserOrderTask: index=0 state=complete status=success ...
#   SendOrderConfirmationTask: index=1 state=complete status=success ...
#   NotifyWarehousePartnersTask: index=2 state=complete status=success ...
#
#   ================================================
#   state: complete | status: success | outcome: success | runtime: 0.5
```

---

- **Prev:** [Basics - Context](context.md)
- **Next:** [Interruptions - Halt](../interruptions/halt.md)
