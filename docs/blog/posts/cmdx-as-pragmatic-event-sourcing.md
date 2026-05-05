---
date: 2026-03-25
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-as-pragmatic-event-sourcing
---

# CMDx as a Pragmatic Alternative to Event Sourcing

*Targets CMDx v1.20.*

Event Sourcing is one of those ideas that sounds perfect in a conference talk and then bankrupts your sprint when you try to implement it. You need an event store, projections, snapshot strategies, a way to replay history, and a team that understands why you can't just `UPDATE` a row anymore. For some domains—banking, audit-heavy compliance, truly distributed systems—it's worth the cost. For the rest of us, it's a complexity tax we can't afford.

But the *benefits* of Event Sourcing are real. An immutable record of what happened. The ability to understand *why* the system is in its current state. Traceability across complex workflows. I wanted those benefits without the infrastructure.

That's when I realized CMDx already gives you most of it for free.

<!-- more -->

## The Complexity Tax

Let me paint a picture. You're building an e-commerce platform in Ruby. Someone suggests Event Sourcing for order management. Suddenly your architecture looks like this:

- **Event Store** — A specialized database (or Postgres with an append-only pattern) for immutable events
- **Aggregates** — Objects that reconstruct their state by replaying events
- **Projections** — Read models built by consuming event streams
- **Snapshots** — Performance optimization for aggregates with long histories
- **Event Bus** — Infrastructure for publishing and subscribing to events

For a team of three building a Rails app, this is a non-starter. You need order tracking and auditability, not a distributed systems thesis.

## Log-Based Event Sourcing

Here's the insight: if every state change in your system goes through a CMDx task, and every task execution is automatically logged with its inputs, outputs, and outcome—you already have an event log.

Let me show you what I mean.

```ruby
class Orders::Process < CMDx::Task
  required :order_id, type: :integer
  required :user_id, type: :integer

  def work
    order = Order.find(order_id)
    order.process!
    context.order = order
    context.processed_at = Time.current
  end
end

result = Orders::Process.execute(order_id: 42, user_id: 7)
```

CMDx automatically logs:

```json
{
  "index": 0,
  "chain_id": "018c2b95-b764-7615-a924-cc5b910ed1e5",
  "class": "Orders::Process",
  "state": "complete",
  "status": "success",
  "metadata": { "runtime": 23 }
}
```

That log entry is, functionally, an event. It tells you:

- **What happened**: `Orders::Process` executed
- **When**: Timestamp
- **The intent**: The inputs (order_id, user_id) that caused the action
- **The outcome**: Success, with runtime metrics
- **Correlation**: A `chain_id` that links this to related operations

Now imagine every business operation in your system flows through CMDx tasks. Your logs become a complete, chronological ledger of system behavior.

## Building the Audit Trail

Let's build a real inventory management system that demonstrates this pattern.

### The Tasks

```ruby
class Inventory::ReceiveStock < CMDx::Task
  required :sku, presence: true
  required :quantity, type: :integer, numeric: { min: 1 }
  required :warehouse_id, type: :integer

  returns :stock_record

  def work
    product = Product.find_by!(sku: sku)
    stock = product.stock_records.create!(
      warehouse_id: warehouse_id,
      quantity: quantity,
      direction: :inbound
    )
    product.increment!(:available_quantity, quantity)

    context.stock_record = stock
    context.new_quantity = product.reload.available_quantity

    logger.info "Received #{quantity} units of #{sku} at warehouse #{warehouse_id}"
  end
end
```

```ruby
class Inventory::ReserveStock < CMDx::Task
  required :sku, presence: true
  required :quantity, type: :integer, numeric: { min: 1 }
  required :order_id, type: :integer

  def work
    product = Product.find_by!(sku: sku)

    if product.available_quantity < quantity
      fail!("Insufficient stock", code: :out_of_stock,
        available: product.available_quantity, requested: quantity)
    end

    product.decrement!(:available_quantity, quantity)
    product.increment!(:reserved_quantity, quantity)

    context.reserved_at = Time.current

    logger.info "Reserved #{quantity} units of #{sku} for order #{order_id}"
  end

  def rollback
    product = Product.find_by!(sku: sku)
    product.increment!(:available_quantity, quantity)
    product.decrement!(:reserved_quantity, quantity)

    logger.info "Released reservation of #{quantity} units of #{sku}"
  end
end
```

```ruby
class Inventory::FulfillStock < CMDx::Task
  required :sku, presence: true
  required :quantity, type: :integer
  required :order_id, type: :integer
  required :warehouse_id, type: :integer

  def work
    product = Product.find_by!(sku: sku)

    if product.reserved_quantity < quantity
      fail!("Reservation mismatch", code: :reservation_error)
    end

    product.decrement!(:reserved_quantity, quantity)
    product.stock_records.create!(
      warehouse_id: warehouse_id,
      quantity: quantity,
      direction: :outbound,
      order_id: order_id
    )

    context.fulfilled_at = Time.current
  end
end
```

### Inbound: Standalone Tasks

`ReceiveStock` runs independently—when a shipment arrives, a warehouse worker or webhook triggers it:

```ruby
result = Inventory::ReceiveStock.execute(sku: "SKU-1234", quantity: 100, warehouse_id: 1)
```

That single execution produces a log entry. No workflow, no ceremony—just one task, one event in the ledger.

### Outbound: Task-in-Task Composition

You don't need a workflow to get chain correlation. When one task calls another, they automatically share the same `chain_id`:

```ruby
class Inventory::ProcessOrder < CMDx::Task
  required :sku, presence: true
  required :quantity, type: :integer, numeric: { min: 1 }
  required :order_id, type: :integer
  required :warehouse_id, type: :integer

  def work
    Inventory::ReserveStock.execute(sku: sku, quantity: quantity, order_id: order_id)
    Inventory::FulfillStock.execute(
      sku: sku, quantity: quantity, order_id: order_id, warehouse_id: warehouse_id
    )
  end
end
```

No `include CMDx::Workflow`, no `task` declarations—just plain calls inside `work`. The logs still correlate:

```json
{"index":1,"chain_id":"abc123","class":"Inventory::ReserveStock","status":"success","metadata":{"runtime":12}}
{"index":2,"chain_id":"abc123","class":"Inventory::FulfillStock","status":"success","metadata":{"runtime":8}}
{"index":0,"chain_id":"abc123","class":"Inventory::ProcessOrder","status":"success","metadata":{"runtime":24}}
```

Every subtask joins the parent's chain automatically. The event log is identical to what a workflow would produce.

### Outbound: Workflow Composition

If you prefer declarative orchestration with breakpoints and conditional steps, a workflow gives you the same chain correlation with less boilerplate:

```ruby
class Inventory::ProcessOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task Inventory::ReserveStock
  task Inventory::FulfillStock
end
```

Either approach produces the same event stream. The key insight is that chain correlation isn't a workflow feature—it's a CMDx feature. Any task calling another task inherits the chain.

Filter by `chain_id` and you see the complete lifecycle of that inventory movement. Filter by class name and you see every stock reservation across your entire system. Filter by status and you find every failure.

This is your event stream—without an event store.

## Reconstructability

Traditional Event Sourcing lets you replay events to reconstruct state. CMDx gives you something similar: because each task encapsulates all inputs needed for an action, you can reconstruct what happened by inspecting the command history.

Consider a support ticket: "Why does product SKU-1234 show 0 available?"

With CMDx logs shipped to your log aggregator, you query:

```
class:"Inventory::*" AND metadata.sku:"SKU-1234" | sort timestamp
```

And get back:

```
10:00 Inventory::ReceiveStock  status:success  quantity:100  warehouse:1
10:15 Inventory::ReserveStock  status:success  quantity:50   order:201
10:16 Inventory::ReserveStock  status:success  quantity:30   order:202
10:17 Inventory::ReserveStock  status:success  quantity:20   order:203
10:30 Inventory::FulfillStock  status:success  quantity:50   order:201
10:45 Inventory::ReserveStock  status:failed   quantity:10   reason:"Insufficient stock"
```

You can trace the exact sequence of events that led to the current state. No event store, no replay mechanism—just structured logs from tasks that were going to run anyway.

## The CQRS Angle

CQRS (Command Query Responsibility Segregation) splits your system into a write model and a read model. With CMDx, this maps naturally:

- **Write Model**: CMDx tasks that perform state changes, logged automatically
- **Read Model**: Your standard ActiveRecord models and database queries

Your relational database serves current-state queries efficiently (the read side), while your CMDx logs provide the historical record of how that state was reached (the write side). You get CQRS-like benefits without maintaining separate projections.

```ruby
# Write side — all mutations go through tasks
class Accounts::Credit < CMDx::Task
  required :account_id, type: :integer
  required :amount, type: :big_decimal, numeric: { min: 0.01 }
  required :reason, presence: true

  returns :transaction

  def work
    account = Account.find(account_id)
    context.transaction = account.transactions.create!(
      amount: amount,
      direction: :credit,
      reason: reason,
      balance_after: account.balance + amount
    )
    account.increment!(:balance, amount)

    logger.info "Credited #{amount} to account #{account_id}: #{reason}"
  end
end
```

```ruby
# Read side — standard queries
account = Account.find(42)
account.balance                                    # Current state
account.transactions.where(direction: :credit)     # Historical data
```

The task logs add another dimension: they capture *intent* and *outcome* that the database alone can't express. A failed credit attempt doesn't create a transaction record, but the CMDx log captures that it was attempted, why it failed, and what data was involved.

## When to Use This vs. Real Event Sourcing

This approach works great when you need:

- **Audit trails** without infrastructure overhead
- **Debugging** complex workflows in production
- **Compliance** reporting on who did what and when
- **Incident analysis** tracing the sequence of actions that led to a state

Stick with real Event Sourcing when you need:

- **Event replay** to rebuild state from scratch
- **Temporal queries** ("What was the account balance on March 1st?")
- **Event-driven microservices** where events are the integration contract
- **Bi-temporal modeling** with correction semantics

For most Ruby applications, the pragmatic approach covers 80% of the use cases at 10% of the complexity.

## Key Takeaways

1. **Every CMDx task execution is an event.** Structured logs with chain correlation, timing, and metadata give you an immutable record of system behavior.

2. **Tasks encapsulate intent.** The inputs to a task capture *why* an action was taken, not just the resulting state change.

3. **Chain IDs are correlation IDs.** Filter by `chain_id` and reconstruct the full lifecycle of any business process.

4. **Your database is the read model.** Query it for current state. Query your logs for history and intent.

5. **Start simple.** Route all state changes through CMDx tasks. The audit trail builds itself.

You don't need an event store to think in events. You just need discipline about where state changes happen—and a framework that makes that discipline effortless.

Happy coding!

## References

- [Comparison](https://drexed.github.io/cmdx/comparison/)
- [Logging](https://drexed.github.io/cmdx/logging/)
- [Chain](https://drexed.github.io/cmdx/basics/chain/)
- [Workflows](https://drexed.github.io/cmdx/workflows/)
