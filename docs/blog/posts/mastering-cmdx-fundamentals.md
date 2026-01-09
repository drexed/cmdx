---
date: 2026-01-07
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-fundamentals
---

# Mastering CMDx Fundamentals: Tasks, Context, Execution, and Chains

When I first started building CMDx, I focused obsessively on four concepts: tasks, context, execution, and chains. These aren't just implementation details—they're the mental model that makes everything else click. Once you understand how they work together, you'll write cleaner business logic and debug issues faster.

Let me walk you through each piece, building from a simple task to a fully orchestrated task.

<!-- more -->

## The Task: Your Unit of Work

A task is where your business logic lives. It's a single, focused unit of work. No more, no less.

```ruby
class SendWelcomeEmail < CMDx::Task
  def work
    user = User.find(context.user_id)
    WelcomeMailer.deliver(user.email)
    context.email_sent_at = Time.current
  end
end
```

That's the entire contract: inherit from `CMDx::Task`, define a `work` method. If you forget the `work` method, CMDx reminds you immediately:

```ruby
class IncompleteTask < CMDx::Task
  # Oops, forgot work
end

IncompleteTask.execute #=> raises CMDx::UndefinedMethodError
```

I designed tasks to be single-use. Once executed, they freeze. You can't run the same task instance twice—that's intentional. Each execution is isolated, traceable, and predictable.

### The Task Lifecycle

Every task follows the same path:

1. **Instantiation** — Task created, context initialized
2. **Validation** — Attributes checked (if you've defined any)
3. **Execution** — Your `work` method runs
4. **Completion** — Result finalized, task frozen

Here's what that looks like in practice:

```ruby
task = SendWelcomeEmail.new(user_id: 42)

# Before execution
task.result.state   #=> "initialized"
task.result.status  #=> "success"

# Execute
task.execute

# After execution
task.result.state   #=> "complete"
task.result.status  #=> "success"
task.frozen?        #=> true
```

### Undoing Work with Rollback

Sometimes things go wrong downstream and you need to undo what you did. That's what `rollback` is for:

```ruby
class ChargeCard < CMDx::Task
  def work
    context.charge = Stripe::Charge.create(
      amount: context.amount_cents,
      customer: context.stripe_customer_id
    )
  end

  def rollback
    Stripe::Refund.create(charge: context.charge.id) if context.charge
  end
end
```

Rollbacks trigger automatically when a task fails. Your charge goes through, the next step bombs, and CMDx calls your `rollback` to void it. No manual cleanup orchestration needed.

## Context: Your Data Container

Context isn’t an abstraction accident—it exists to solve deterministic data flow between tasks. Unlike instance variables, it explicitly models inputs, outputs, and intermediate values as a shared contract.

### Putting Data In

Every key-value pair you pass becomes part of the context:

```ruby
result = ProcessOrder.execute(
  order_id: 123,
  user: current_user,
  options: { expedite: true }
)
```

String keys automatically convert to symbols. You can pass a hash, keyword arguments, or even an existing context from a previous task (it's what makes Ruby powerful IMHO 🌟).

### Getting Data Out

Access context data however feels natural:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Method style (my preference)
    order = Order.find(context.order_id)

    # Hash style
    user = context[:user]

    # Safe access with defaults
    expedite = context.fetch(:expedite, false)

    # Nested digging
    carrier = context.dig(:options, :preferred_carrier)

    # Shorter alias works too
    priority = ctx.priority
  end
end
```

Accessing undefined keys returns `nil` instead of raising errors. That's intentional—optional data shouldn't require defensive coding.

### Modifying Context

Context is your scratchpad during execution:

```ruby
class ProcessOrder < CMDx::Task
  def work
    order = Order.find(context.order_id)

    # Direct assignment
    context.order = order
    context.processed_at = Time.current

    # Conditional assignment
    context.tracking_number ||= generate_tracking_number

    # Batch updates
    context.merge!(
      status: "processing",
      estimated_ship_date: 3.days.from_now
    )

    # Remove sensitive data before logging
    context.delete!(:credit_card_number)
  end
end
```

### Sharing Context Between Tasks

Here's where context really shines. Tasks naturally chain together:

```ruby
class CreateOrder < CMDx::Task
  def work
    context.order = Order.create!(
      user_id: context.user_id,
      items: context.items
    )
  end
end

class ProcessPayment < CMDx::Task
  def work
    # context.order is available from the previous task
    charge = PaymentGateway.charge(
      amount: context.order.total,
      customer_id: context.user_id
    )
    context.payment = charge
  end
end

class SendConfirmation < CMDx::Task
  def work
    # Both order and payment are available
    OrderMailer.confirmation(
      order: context.order,
      payment: context.payment
    ).deliver_now
  end
end
```

In a workflow, each task builds on what came before:

```ruby
# Execute first task
result = CreateOrder.execute(user_id: 42, items: cart_items)

# Pass context to next task
ProcessPayment.execute(result.context)

# And the next
SendConfirmation.execute(result.context)
```

The context accumulates data as it flows through your pipeline. No global state, no hidden dependencies—just explicit data flow.

## Execution: Two Flavors, One Result

CMDx gives you two ways to run tasks: `execute` and `execute!`. Choose based on how you want to handle problems.

### The Safe Path: `execute`

Always returns a result, never raises:

```ruby
result = SendWelcomeEmail.execute(user_id: 42)

if result.success?
  puts "Email sent at #{result.context.email_sent_at}"
elsif result.failed?
  puts "Failed: #{result.reason}"
  log_failure(result.cause) if result.cause # Original exception
elsif result.skipped?
  puts "Skipped: #{result.reason}"
end
```

I use this 90% of the time. The result tells me everything I need to know without try/catch ceremony.

### The Assertive Path: `execute!`

Raises exceptions on failure, returns results only on success:

```ruby
begin
  result = CreateAccount.execute!(email: params[:email])
  redirect_to dashboard_path

rescue CMDx::FailFault => e
  flash[:error] = e.result.reason
  render :new

rescue CMDx::SkipFault => e
  flash[:notice] = "Account already exists"
  redirect_to login_path
end
```

Use `execute!` when a failure should halt everything. It's great for controller actions where you want to handle the exception at a higher level.

### Inspecting Results

The result object is packed with useful information:

```ruby
result = ProcessOrder.execute(order_id: 123)

# What happened?
result.state      #=> "complete"
result.status     #=> "success"
result.success?   #=> true
result.failed?    #=> false
result.skipped?   #=> false

# The data
result.context    #=> Context with all accumulated data
result.metadata   #=> Execution metadata hash

# Traceability
result.id         #=> Unique execution ID
result.task       #=> The frozen task instance
result.chain      #=> The execution chain
```

### Dry Run Mode

Sometimes you want to simulate execution without side effects. Pass `dry_run: true`:

```ruby
class CancelSubscription < CMDx::Task
  def work
    if dry_run?
      context.would_cancel = true
      context.refund_amount = calculate_prorated_refund
    else
      Stripe::Subscription.delete(context.subscription_id)
      context.cancelled_at = Time.current
    end
  end
end

# Simulate
result = CancelSubscription.execute(subscription_id: "sub_123", dry_run: true)
result.context.would_cancel   #=> true
result.context.refund_amount  #=> 47.50

# For real
result = CancelSubscription.execute(subscription_id: "sub_123")
result.context.cancelled_at   #=> 2025-01-08 14:32:15 UTC
```

Perfect for preview features, admin dashboards, or testing what *would* happen.

## Chains: Your Execution Trail

Every task execution creates or joins a chain. Think of it as an automatic audit trail that tracks what happened, in what order, across related tasks.

### Automatic Chain Management

You don't have to think about chains—they happen automatically:

```ruby
class ImportData < CMDx::Task
  def work
    # First subtask starts a chain (or joins existing)
    result1 = ValidateSchema.execute(context)

    # Second subtask joins the same chain
    result2 = TransformData.execute(context)

    # Third subtask, same chain
    result3 = SaveRecords.execute(context)

    # All share the same chain ID
    result1.chain.id == result2.chain.id  #=> true
    result2.chain.id == result3.chain.id  #=> true
  end
end

result = ImportData.execute(file_path: "/data/import.csv")
chain = result.chain

chain.id             #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results.size   #=> 4 (parent + 3 subtasks)
chain.results.map { |r| r.task.class.name }
#=> ["ImportData", "ValidateSchema", "TransformData", "SaveRecords"]
```

### Thread Safety

Chains are thread-local. Each thread gets its own isolated chain:

```ruby
Thread.new do
  result = BatchJob.execute(batch_id: 1)
  result.chain.id  #=> "abc123..."
end

Thread.new do
  result = BatchJob.execute(batch_id: 2)
  result.chain.id  #=> "xyz789..."  # Completely different
end
```

This means parallel job workers never step on each other's chains. No race conditions, no cross-contamination.

### Chain State

The chain's state reflects the outermost task:

```ruby
result = ImportData.execute(file_path: "/data/import.csv")
chain = result.chain

chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"

# Individual subtask results maintain their own states
chain.results.each do |r|
  puts "#{r.task.class}: #{r.status}"
end
# ImportData: success
# ValidateSchema: success
# TransformData: skipped  (maybe data was already transformed)
# SaveRecords: success
```

## Key Takeaways

1. **Tasks are single-purpose** — One `work` method, one responsibility. Use `rollback` for cleanup.

2. **Context is your data pipeline** — Pass it between tasks. Let it accumulate. Don't fight it with instance variables.

3. **Choose your execution style** — `execute` for result-based flow, `execute!` for exception-based control.

4. **Chains are automatic** — They track everything. Use them for debugging, logging, and auditing.

5. **Dry run for safety** — Preview what would happen before doing it for real.

These fundamentals are the foundation for everything else in CMDx—attributes, callbacks, workflows, middlewares. Master these four concepts and you'll be building robust business logic in no time.

Happy coding!
