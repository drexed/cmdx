# Basics - Chain

Chains automatically group related task executions within a thread, providing unified tracking, correlation, and execution context management. Each thread maintains its own chain through thread-local storage, eliminating the need for manual coordination.

## Table of Contents

- [TLDR](#tldr)
- [Thread-Local Chain Management](#thread-local-chain-management)
- [Automatic Chain Creation](#automatic-chain-creation)
- [Chain Inheritance](#chain-inheritance)
- [Chain Structure and Metadata](#chain-structure-and-metadata)
- [Correlation ID Integration](#correlation-id-integration)
- [State Delegation](#state-delegation)
- [Serialization and Logging](#serialization-and-logging)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Automatic chain creation per thread
result = ProcessOrderTask.call(order_id: 123)
result.chain.id           # Unique chain ID
result.chain.results.size # All tasks in this chain

# Access current thread's chain
CMDx::Chain.current  # Current chain or nil
CMDx::Chain.clear    # Clear thread's chain

# Subtasks automatically inherit chain
class ProcessOrder < CMDx::Task
  def call
    # These inherit the same chain automatically
    ValidateOrderTask.call!(order_id: order_id)
    ChargePaymentTask.call!(order_id: order_id)
  end
end
```

## Thread-Local Chain Management

> [!NOTE]
> Each thread maintains its own chain context through thread-local storage, providing automatic isolation without manual coordination.

```ruby
# Thread A
Thread.new do
  result = ProcessOrderTask.call(order_id: 123)
  result.chain.id    # "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B (completely separate chain)
Thread.new do
  result = ProcessOrderTask.call(order_id: 456)
  result.chain.id    # "018c2b95-c821-7892-b156-dd7c921fe2a3"
end

# Access current thread's chain
CMDx::Chain.current  # Returns current chain or nil
CMDx::Chain.clear    # Clears current thread's chain
```

## Automatic Chain Creation

Every task execution automatically creates or joins the current thread's chain:

```ruby
# First task creates new chain
result1 = ProcessOrderTask.call(order_id: 123)
result1.chain.id           # "018c2b95-b764-7615-a924-cc5b910ed1e5"
result1.chain.results.size # 1

# Second task joins existing chain
result2 = SendEmailTask.call(to: "user@example.com")
result2.chain.id == result1.chain.id  # true
result2.chain.results.size            # 2

# Both results reference the same chain
result1.chain.results == result2.chain.results  # true
```

## Chain Inheritance

> [!IMPORTANT]
> When tasks call subtasks within the same thread, all executions automatically inherit the current chain, creating a unified execution trail.

```ruby
class ProcessOrder < CMDx::Task
  def call
    context.order = Order.find(order_id)

    # Subtasks automatically inherit current chain
    ValidateOrderTask.call!(order_id: order_id)
    ChargePaymentTask.call!(order_id: order_id)
    SendConfirmationTask.call!(order_id: order_id)
  end
end

result = ProcessOrderTask.call(order_id: 123)
chain = result.chain

# All tasks share the same chain
chain.results.size # 4 (main task + 3 subtasks)
chain.results.map(&:task).map(&:class)
# [ProcessOrderTask, ValidateOrderTask, ChargePaymentTask, SendConfirmationTask]
```

## Chain Structure and Metadata

Chains provide comprehensive execution information with state delegation:

```ruby
result = ProcessOrderTask.call(order_id: 123)
chain = result.chain

# Chain identification
chain.id      # "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results # Array of all results in execution order

# State delegation (from first/outer-most result)
chain.state   # "complete"
chain.status  # "success"
chain.outcome # "success"
chain.runtime # 1.2 (total execution time)

# Access individual results
chain.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class} - #{result.status}"
end
```

## Correlation ID Integration

> [!TIP]
> Chain IDs serve as correlation identifiers, enabling request tracing across distributed systems and complex workflows.

### Automatic Correlation

Chains integrate with the correlation system using hierarchical precedence:

```ruby
# 1. Existing chain ID takes precedence
CMDx::Chain.current = CMDx::Chain.new(id: "request-123")
result = ProcessOrderTask.call(order_id: 456)
result.chain.id # "request-123"

# 2. Thread-local correlation used if no chain exists
CMDx::Chain.clear
CMDx::Correlator.id = "session-456"
result = ProcessOrderTask.call(order_id: 789)
result.chain.id # "session-456"

# 3. Generated UUID when no correlation exists
CMDx::Correlator.clear
result = ProcessOrderTask.call(order_id: 101)
result.chain.id # "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated)
```

### Custom Chain IDs

```ruby
# Create chain with specific correlation ID
chain = CMDx::Chain.new(id: "api-request-789")
CMDx::Chain.current = chain

result = ProcessApiRequestTask.call(data: payload)
result.chain.id # "api-request-789"

# All subtasks inherit the same correlation ID
result.chain.results.all? { |r| r.chain.id == "api-request-789" } # true
```

### Correlation Context Management

```ruby
# Scoped correlation context
CMDx::Correlator.use("user-session-123") do
  result = ProcessUserActionTask.call(action: "purchase")
  result.chain.id # "user-session-123"

  # Nested operations inherit correlation
  AuditLogTask.call(event: "purchase_completed")
end

# Outside block, correlation context restored
result = OtherTask.call
result.chain.id # Different correlation ID
```

## State Delegation

> [!WARNING]
> Chain state always reflects the first (outer-most) task result, not individual subtask outcomes. Subtasks maintain their own success/failure states.

```ruby
class ProcessOrder < CMDx::Task
  def call
    ValidateOrderTask.call!(order_id: order_id)    # Success
    ChargePaymentTask.call!(order_id: order_id)    # Failure
  end
end

result = ProcessOrderTask.call(order_id: 123)
chain = result.chain

# Chain delegates to main task (first result)
chain.status  # "failed" (ProcessOrderTask failed due to subtask)
chain.state   # "interrupted"

# Individual results maintain their own state
chain.results[0].status # "failed"  (ProcessOrderTask - main)
chain.results[1].status # "success" (ValidateOrderTask)
chain.results[2].status # "failed"  (ChargePaymentTask)
```

## Serialization and Logging

Chains provide comprehensive serialization for monitoring and debugging:

```ruby
result = ProcessOrderTask.call(order_id: 123)
chain = result.chain

# Structured data representation
chain.to_h
# {
#   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
#   state: "complete",
#   status: "success",
#   outcome: "success",
#   runtime: 0.8,
#   results: [
#     { class: "ProcessOrderTask", state: "complete", status: "success", ... },
#     { class: "ValidateOrderTask", state: "complete", status: "success", ... },
#     { class: "ChargePaymentTask", state: "complete", status: "success", ... }
#   ]
# }

# Human-readable execution summary
puts chain.to_s
# chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
# ================================================
#
# ProcessOrderTask: index=0 state=complete status=success runtime=0.8
# ValidateOrderTask: index=1 state=complete status=success runtime=0.1
# ChargePaymentTask: index=2 state=complete status=success runtime=0.5
#
# ================================================
# state: complete | status: success | outcome: success | runtime: 0.8
```

## Error Handling

### Chain Access Patterns

```ruby
# Safe chain access
result = ProcessOrderTask.call(order_id: 123)

if result.chain
  correlation_id = result.chain.id
  execution_count = result.chain.results.size
else
  # Handle missing chain (shouldn't happen in normal execution)
  correlation_id = "unknown"
end
```

### Thread Safety

> [!IMPORTANT]
> Chain operations are thread-safe within individual threads but chains should not be shared across threads. Each thread maintains its own isolated chain context.

```ruby
# Safe: Each thread has its own chain
threads = 3.times.map do |i|
  Thread.new do
    result = ProcessOrderTask.call(order_id: 100 + i)
    result.chain.id  # Unique per thread
  end
end

# Collect results safely
chain_ids = threads.map(&:value)
chain_ids.uniq.size # 3 (all different)
```

### Chain State Validation

```ruby
result = ProcessOrderTask.call(order_id: 123)
chain = result.chain

# Validate chain integrity
case chain.state
when "complete"
  # All tasks finished normally
  process_successful_chain(chain)
when "interrupted"
  # Task was halted or failed
  handle_chain_interruption(chain)
else
  # Unexpected state
  log_chain_anomaly(chain)
end
```

---

- **Prev:** [Basics - Context](context.md)
- **Next:** [Interruptions - Halt](../interruptions/halt.md)
