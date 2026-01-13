---
date: 2026-01-28
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-workflows
---

# Mastering CMDx Workflows: Orchestrating Complex Business Logic

I remember when my service objects started getting messy. I'd have a `PlaceOrder` service that began as a simple 10-line script but slowly mutated into a 500-line monster handling validation, payments, inventory, shipping, and a dozen notification types. It was a nightmare to test and even harder to read.

That's exactly why I built CMDx Workflows. They allow you to decompose complex processes into small, focused tasks and orchestrate them declaratively. It turns your business logic from a tangled mess of `if` statements into a clean, readable pipeline.

Let's dive into how workflows can transform your Ruby application's architecture.

<!-- more -->

## The Workflow Pattern

At its core, a workflow is just a `CMDx::Task` that coordinates other tasks. Instead of writing a `work` method with a bunch of procedural code, you declare a sequence of tasks that should run.

Here's the simplest possible workflow:

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ReserveInventory
  task ChargeCard
  task SendReceipt
end
```

When you run `PlaceOrder.execute`, CMDx runs these tasks in order. They share the same context, so if `ValidateCart` sets `context.cart_total`, `ChargeCard` can read it immediately. It's seamless data flow without the plumbing code.

## Conditional Logic

Real world processes are rarely linear. You have edge cases, optional steps, and business rules.

In my order processing example, we faced a common problem: we sold both physical and digital goods. Physical goods need shipping; digital goods need a download link.

CMDx Workflows handle this elegantly with `if` and `unless` conditionals:

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ReserveInventory
  task ChargeCard

  # Only run for physical goods
  task CreateShippingLabel, if: :physical_goods?

  # Only run for digital goods
  task GenerateDownloadLink, unless: :physical_goods?

  task SendReceipt

  private

  def physical_goods?
    context.items.any?(&:physical?)
  end
end
```

You can use methods, Procs, lambdas, or even other classes as conditions. It keeps the high-level flow visible at a glance while hiding the implementation details.

## Grouping Tasks

As our application grew, we added more notifications—SMS, Slack alerts for high-value orders, and email. Instead of repeating conditions for every single task, I used **Groups**:

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  # ... core order logic ...

  # All these tasks share the 'if: :success?' condition
  tasks SendEmailReceipt, SendSmsConfirmation, NotifyAdmins, if: :order_successful?
end
```

This is huge for readability. You can see immediately that this entire block of functionality is conditional.

## Handling Failure (Breakpoints)

By default, if a task in a workflow is skipped, the workflow continues. But if a task fails? You usually want to stop everything.

CMDx lets you control this "halt behavior" precisely using breakpoints.

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  # If validation or inventory fails, stop immediately.
  # We don't want to charge a card for out-of-stock items!
  settings(workflow_breakpoints: ["failed"])

  task ValidateCart
  task ReserveInventory
  task ChargeCard
end
```

If `ReserveInventory` fails, `ChargeCard` never runs. The workflow returns a failed result, and you can handle the error gracefully at the controller level.

## Composing Workflows (Nested Workflows)

The most powerful feature of workflows is that they are composable. A workflow is just a task, which means a workflow can include *other workflows*.

This allowed us to extract complex subsystems into their own domains. Our fulfillment logic became so complex it needed its own team:

```ruby
class FulfillmentWorkflow < CMDx::Task
  include CMDx::Workflow

  task LocateItems
  task PrintPackingSlip
  task RequestCourierPickup
end

class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ChargeCard

  # Just drop in the sub-workflow
  task FulfillmentWorkflow, if: :physical_goods?
end
```

`PlaceOrder` doesn't need to know how fulfillment works; it just knows it needs to happen. This encapsulation is key to maintaining large Ruby codebases.

## Parallel Execution

Some tasks don't depend on each other and can run simultaneously. Sending notifications is a perfect example—email, SMS, and push notifications are all independent operations.

CMDx supports parallel execution out of the box using the `strategy: :parallel` option:

```ruby
class PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ChargeCard

  # These run concurrently—no waiting for email to finish before SMS
  tasks SendEmailReceipt, SendSmsConfirmation, NotifySlack, strategy: :parallel

  task UpdateAnalytics
end
```

This uses the [Parallel](https://github.com/grosser/parallel) gem under the hood (must be installed in your app or execution environment), automatically utilizing all available processors. You can also fine-tune with `in_threads` or `in_processes`:

```ruby
# Fixed thread pool
tasks SendEmailReceipt, SendSmsConfirmation, strategy: :parallel, in_threads: 2

# Forked processes (for CPU-bound work)
tasks GeneratePdf, GenerateCsv, strategy: :parallel, in_processes: 2
```

One gotcha: **context is read-only during parallel execution**. Since tasks run simultaneously, allowing writes would create race conditions. Load all the data you need before the parallel block, and aggregate results afterward.

## Wrapping Up

Workflows changed how I think about service objects. Instead of writing code that *does* things, I write code that *describes* what should be done.

1. **Start simple**: List your steps as tasks.
2. **Add flow control**: Use `if`/`unless` for logic branches.
3. **Group related tasks**: Keep your definitions DRY.
4. **Compose**: Break big workflows into smaller sub-workflows.
5. **Parallelization**: Execute multiple tasks simultaneously.

Give it a try on your next complex feature. You'll find yourself writing less glue code and more focused business logic.

## References

- [Workflows](https://drexed.github.io/cmdx/workflows/)
