---
date: 2026-01-01
authors:
  - drexed
categories:
  - Tutorials
slug: getting-started-with-cmdx
---

# Getting Started with CMDx: Taming Business Logic in Ruby

I've spent years wrestling with service objects. You know the pattern—create a class, throw some business logic in a `call` method, cross your fingers, and hope for the best. The problem? Every team member writes them differently. Every project invents its own conventions. And when something breaks at 2 AM, good luck tracing what actually happened.

That frustration led me to create CMDx.

<!-- more -->

## The Problem with Service Objects

Let's be honest about what we're dealing with. Your typical Rails service object looks something like this:

```ruby
class ProcessOrder
  def initialize(order_id, user)
    @order_id = order_id
    @user = user
  end

  def call
    order = Order.find(@order_id)
    return false if order.processed?

    order.process!
    OrderMailer.confirmation(@user).deliver_now
    true
  rescue => e
    Rails.logger.error("Order processing failed: #{e.message}")
    false
  end
end
```

What's wrong with this? Everything and nothing. It works, but:

- **Inconsistent patterns** — Does it return `true`/`false`? An object? Raises exceptions? Every service decides differently.
- **Black box execution** — When something fails in production, you're left grepping logs hoping someone remembered to add useful output.
- **Fragile error handling** — That `rescue => e` catches *everything*. Validation errors, network timeouts, database issues—all get the same treatment.

These aren't hypothetical problems. They're the Monday morning fire drills that eat your week.

## Why I Built CMDx

I wanted something simple enough for a junior dev to pick up in an afternoon, but powerful enough to handle complex business processes. CMDx is built around a straightforward pattern I call CERO: **Compose, Execute, React, Observe**.

The idea is that every piece of business logic should:

1. Be **composed** as a self-contained task
2. **Execute** with consistent, predictable behavior
3. Return a **result** you can react to
4. Be **observable** through structured logging

Let me show you what this looks like in practice.

## Your First CMDx Task

Here's the simplest possible task:

```ruby
class ProcessOrder < CMDx::Task
  def work
    order = Order.find(context.order_id)
    order.process!
    context.processed_at = Time.current
  end
end
```

That's it. Inherit from `CMDx::Task`, define a `work` method, and you're done.

The `context` object is your data container—it holds everything you pass in and everything you want to pass out. No instance variables to juggle, no wondering what data is available where.

Let's execute it:

```ruby
result = ProcessOrder.execute(order_id: 42)
```

Every execution returns a `Result` object. Always. No exceptions (pun intended—we'll get to those).

## Reacting to Outcomes

Here's where CMDx starts earning its keep. The result tells you exactly what happened:

```ruby
result = ProcessOrder.execute(order_id: 42)

if result.success?
  puts "Order processed at #{result.context.processed_at}"
elsif result.skipped?
  puts "Order was skipped: #{result.reason}"
elsif result.failed?
  puts "Order failed: #{result.reason}"
end
```

Three possible statuses: `success`, `skipped`, or `failed`. That's it. No mystery booleans, no exceptions to catch (unless you want them), no guessing what happened.

## Controlling Execution Flow

Real business logic isn't a straight line. Sometimes you need to stop early, sometimes things go wrong. CMDx gives you two explicit methods for this: `skip!` and `fail!`.

### Skipping: When There's Nothing to Do

Use `skip!` when the task legitimately shouldn't run. It's a no-op, not an error:

```ruby
class ProcessOrder < CMDx::Task
  def work
    order = Order.find(context.order_id)

    if order.already_processed?
      skip!("Order was already processed on #{order.processed_at}")
    end

    order.process!
    context.processed_at = Time.current
  end
end
```

Skipped tasks are considered *successful outcomes*—the task did exactly what it should by recognizing there was nothing to do.

### Failing: When Something Goes Wrong

Use `fail!` when the task cannot complete. This is an intentional, controlled failure:

```ruby
class ProcessOrder < CMDx::Task
  def work
    order = Order.find_by(id: context.order_id)

    if order.nil?
      fail!("Order not found", code: :not_found)
    elsif order.expired?
      fail!("Order has expired", code: :expired, expired_at: order.expired_at)
    end

    order.process!
    context.processed_at = Time.current
  end
end
```

Notice the metadata I'm passing—`code`, `expired_at`. This gets captured in the result:

```ruby
result = ProcessOrder.execute(order_id: 999)

if result.failed?
  puts result.reason              # => "Order not found"
  puts result.metadata[:code]     # => :not_found
end
```

### Handling Real Exceptions

What about actual exceptions—database timeouts, network failures, unexpected nil values? CMDx catches these and converts them to failures automatically:

```ruby
result = ProcessOrder.execute(order_id: 42)

if result.failed?
  puts result.reason  # => "[ActiveRecord::ConnectionError] Connection timed out"
  puts result.cause   # => The actual exception object
end
```

Your code doesn't change. The result still tells you what happened, the exception is still available if you need it for debugging, but your calling code doesn't need a `rescue` block.

## Observing Everything

This is my favorite part. Every CMDx execution automatically logs what happened:

```log
I, [2025-01-07T14:32:15.000000 #3784] INFO -- CMDx:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="ProcessOrder" state="complete" status="success" metadata={runtime: 47}
```

Every execution. Automatically. With timing, chain correlation, and outcome status.

When something fails:

```log
I, [2025-01-07T14:32:17.000000 #3784] INFO -- CMDx:
index=0 chain_id="018c2b95-c921-8834-b234-dd6c721fe3a7" type="Task" class="ProcessOrder" state="interrupted" status="failed" metadata={code: :not_found} reason="Order not found"
```

You can also log from within your task:

```ruby
class ProcessOrder < CMDx::Task
  def work
    logger.debug { "Looking up order #{context.order_id}" }

    order = Order.find(context.order_id)
    order.process!

    logger.info "Order #{order.id} processed successfully"
    context.processed_at = Time.current
  end
end
```

## What's Next

This introduction covers the foundation—tasks, execution, halting, and observability. But CMDx has more to offer:

- **Attributes** with type coercion and validation
- **Callbacks** for cross-cutting concerns
- **Workflows** for orchestrating multi-step processes
- **Middlewares** for wrapping execution with custom behavior
- **Retries** for handling transient failures

Check out the [full documentation](https://drexed.github.io/cmdx) to explore these features.

The goal of CMDx is simple: make your business logic predictable, observable, and maintainable. No more 2 AM mysteries. No more inconsistent patterns. Just clean, focused tasks that tell you exactly what they did.

Give it a try! I'd love to hear how it works for you.
