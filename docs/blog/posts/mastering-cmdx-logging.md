---
date: 2026-02-18
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-logging
---

# Mastering CMDx: The Art of Observability with Logging

We've all been there. A production incident report lands on your desk. "Transaction failed for user X." You open the logs, grep for the user ID, and... silence. Or worse, a wall of unstructured text that tells you everything except what you need to know.

Logging is often an afterthought—something we sprinkle in `rescue` blocks when we're debugging. But in CMDx, the Ruby framework for business logic, observability isn't an add-on; it's a first-class citizen.

<!-- more -->

## The Default Experience

When I built CMDx, I wanted to ensure that you never had to guess *if* a task ran. By default, every single task execution is logged. You don't have to configure anything.

Run a task:

```ruby
class CreateUser < CMDx::Task
  def work
    # ...
  end
end

CreateUser.call
```

And check your output:

```log
I, [2026-01-09T10:00:00.000000 #1234] INFO -- cmdx: {index: 0, chain_id: "...", type: "Task", class: "CreateUser", state: "complete", status: "success", ...}
```

Right out of the box, you get:

- **Who**: The class name (`CreateUser`)
- **When**: Timestamp
- **What**: The outcome (`success`, `failed`, `skipped`)
- **How long**: Runtime metadata

## Choosing Your Style

While the default output is great for development, your production environment might need something different. CMDx supports multiple formatters to fit your stack.

### For the Humans (Line Formatter)

If you're tailing logs in a terminal, you might prefer the `Line` formatter. It's concise and readable.

```ruby
CMDx.configure do |config|
  config.log_formatter = CMDx::LogFormatters::Line.new
end
```

### For the Machines (JSON Formatter)

If you're shipping logs to Datadog, Splunk, or CloudWatch, structured JSON is king.

```ruby
CMDx.configure do |config|
  config.log_formatter = CMDx::LogFormatters::Json.new
end
```

Now your logs are perfectly parseable JSON objects, ready for aggregation and querying.

## Logging Inside Your Tasks

Sometimes the automatic execution log isn't enough. You want to capture specific business events—"Payment gateway contacted", "Inventory check passed".

CMDx exposes a standard logger instance right inside your task context:

```ruby
class ProcessPayment < CMDx::Task
  def work
    logger.info("Contacting payment gateway...")

    charge = PaymentGateway.charge(context.amount)

    logger.info("Charge successful: #{charge.id}")
    context.charge_id = charge.id
  end
end
```

This uses the same logger instance as the framework, ensuring your custom logs are interleaved correctly with the automatic system logs.

## The Power of Correlation

Here is where it gets really cool. When you run a `Workflow` (a chain of tasks), CMDx generates a `chain_id`. This ID is passed down to every single task in that workflow.

If you have a workflow like this:

```ruby
class PlaceOrder < CMDx::Workflow
  step ValidateCart
  step ChargeCard
  step SendEmail
end
```

Every log entry from `ValidateCart`, `ChargeCard`, and `SendEmail` will share the same `chain_id`. You can filter your logs by this ID and see the entire lifecycle of that request, from start to finish, across multiple classes.

```log
I, [2026-01-09T10:00:00.000000 #1234] INFO -- cmdx: {index: 1, chain_id: "a1b2c3d4", class: "ValidateCart", ...}
I, [2026-01-09T10:00:00.100000 #1234] INFO -- cmdx: {index: 2, chain_id: "a1b2c3d4", class: "ChargeCard", ...}
I, [2026-01-09T10:00:00.200000 #1234] INFO -- cmdx: {index: 3, chain_id: "a1b2c3d4", class: "SendEmail", ...}
I, [2026-01-09T10:00:00.300000 #1234] INFO -- cmdx: {index: 0, chain_id: "a1b2c3d4", class: "PlaceOrder", ...}
```

Notice how `chain_id: "a1b2c3d4"` persists across all entries. Even better, the final entry for the `PlaceOrder` workflow wraps it all up, confirming the entire chain succeeded.

## Debugging Failures

When things go wrong, CMDx provides rich context. If a task fails:

```ruby
class ValidateCart < CMDx::Task
  def work
    fail!("Cart is empty", code: :empty_cart)
  end
end
```

The log entry will include:

- The `status` ("failed")
- The `reason` ("Cart is empty")
- The `metadata` (`{code: :empty_cart}`)
- The `chain_id` (so you know which workflow triggered it)

No more guessing *why* something failed. It's right there in the record.

## Conclusion

Good logging is the difference between a five-minute fix and a five-hour headache. CMDx handles the heavy lifting for you, ensuring that every piece of business logic is observable by default.

So go ahead, delete those `puts "HERE"` statements. CMDx has got you covered.
