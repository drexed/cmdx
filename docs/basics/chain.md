# Basics - Chain

Chains automatically group related task executions within a thread, providing unified tracking, correlation, and execution context management. Each thread maintains its own chain through thread-local storage, eliminating the need for manual coordination.

## Table of Contents

- [Management](#management)
- [Links](#links)
- [Inheritance](#inheritance)
- [Structure](#structure)

## Management

Each thread maintains its own chain context through thread-local storage, providing automatic isolation without manual coordination.

```ruby
# Thread A
Thread.new do
  result = ProcessOrder.execute(order_id: 123)
  result.chain.id    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B (completely separate chain)
Thread.new do
  result = ProcessOrder.execute(order_id: 456)
  result.chain.id    #=> "z3a42b95-c821-7892-b156-dd7c921fe2a3"
end

# Access current thread's chain
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current thread's chain
```

> [!IMPORTANT]
> Chain operations are thread-local. Never share chain references across threads as this can lead to race conditions and data corruption.

## Links

Every task execution automatically creates or joins the current thread's chain:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # First task creates new chain
    result1 = ProcessOrder.execute(order_id: 123)
    result1.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
    result1.chain.results.size #=> 1

    # Second task joins existing chain
    result2 = SendEmail.execute(to: "user@example.com")
    result2.chain.id == result1.chain.id  #=> true
    result2.chain.results.size            #=> 2

    # Both results reference the same chain
    result1.chain.results == result2.chain.results #=> true
  end
end
```

> [!NOTE]
> Chain creation is automatic and transparent. You don't need to manually manage chain lifecycle.

## Inheritance

When tasks call subtasks within the same thread, all executions automatically inherit the current chain, creating a unified execution trail.

```ruby
class ProcessOrder < CMDx::Task
  def work
    context.order = Order.find(order_id)

    # Subtasks automatically inherit current chain
    ValidateOrder.execute
    ChargePayment.execute!(context)
    SendConfirmation.execute(order_id: order_id)
  end
end

result = ProcessOrder.execute(order_id: 123)
chain = result.chain

# All tasks share the same chain
chain.results.size #=> 4 (main task + 3 subtasks)
chain.results.map { |r| r.task.class }
#=> [ProcessOrder, ValidateOrder, ChargePayment, SendConfirmation]
```

## Structure

Chains provide comprehensive execution information with state delegation:

```ruby
result = ProcessOrder.execute(order_id: 123)
chain = result.chain

# Chain identification
chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results #=> Array of all results in execution order

# State delegation (from first/outer-most result)
chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"

# Access individual results
chain.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class} - #{result.status}"
end
```

> [!NOTE]
> Chain state always reflects the first (outer-most) task result, not individual subtask outcomes. Subtasks maintain their own success/failure states.

---

- **Prev:** [Basics - Context](context.md)
- **Next:** [Interruptions - Halt](../interruptions/halt.md)
