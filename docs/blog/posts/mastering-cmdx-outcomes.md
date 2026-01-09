---
date: 2026-01-21
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-outcomes
---

# Mastering CMDx Outcomes: Results, States, and Statuses

If you've ever found yourself asking "What does this service object actually return?", you're not alone. Does it return `true`? The record it created? A hash with errors? Or does it just raise an exception and hope someone catches it?

In my experience, inconsistent return values are the silent killers of maintainable Ruby code. That's why CMDx standardizes everything into a single, powerful concept: the **Result**.

<!-- more -->

## The Result Object

When you execute a CMDx task, you *always* get a `Result` object back. It doesn't matter if the task succeeded, failed, skipped, or exploded with an exception—the interface is consistent.

```ruby
result = CreateInvoice.execute(amount: 100, user: current_user)
```

This result object is your single source of truth. It's immutable (so you can pass it around safely), and it carries everything you need to know about what just happened:

- **Context**: The data that went in and came out (`result.context`)
- **Outcome**: Whether it worked (`result.success?`)
- **Metadata**: Error codes, timing information, and more (`result.metadata`)

But here's where it gets interesting. CMDx breaks down the "outcome" into two distinct concepts: **State** and **Status**.

## State vs. Status: The Critical Distinction

I often see developers conflate "lifecycle" with "outcome". In CMDx, we separate them cleanly.

### State: The Lifecycle
**State** tells you *how far* the execution got. It answers: "Did the code finish running?"

- `initialized`: The task was created but hasn't started.
- `executing`: The code is currently running (transient).
- `complete`: The code finished from top to bottom without interruption.
- `interrupted`: The execution was stopped early (by a failure, a manual halt, or an exception).

### Status: The Business Outcome
**Status** tells you *what happened* in business terms. It answers: "Did we do what we intended?"

- `success`: We did the thing! (Default)
- `skipped`: We didn't do the thing, but that's okay (e.g., "Invoice already sent").
- `failed`: We couldn't do the thing (e.g., "Validation error").

### The Matrix

Understanding how these combine is powerful. Here are the most common scenarios:

| State | Status | What it means |
|-------|--------|---------------|
| `complete` | `success` | The happy path. Code ran, job done. |
| `interrupted` | `failed` | Something broke or we called `fail!`. |
| `interrupted` | `skipped` | We called `skip!` to stop early. |
| `complete` | `skipped` | We ran everything but decided to mark it as skipped at the end. |

This separation lets you write precise logic. You might want to log all `interrupted` tasks for debugging, but only alert on `failed` statuses.

## Handling Outcomes Like a Pro

Now that we have this rich data, how do we use it? CMDx gives you three ways to handle results, ranging from simple to sophisticated.

### 1. The Predicate Check (Simple)

Good for simple control flow:

```ruby
result = CreateInvoice.execute(amount: 100)

if result.success?
  redirect_to invoice_path(result.context.invoice)
elsif result.skipped?
  flash[:notice] = "Invoice already exists."
  redirect_to invoice_path(result.context.invoice)
else
  # result.failed?
  @errors = result.reason
  render :new
end
```

You also have helpful grouping predicates like `result.good?` (success or skipped) and `result.bad?` (failed or skipped).

### 2. The Fluent Handlers (Functional)

My personal favorite. This style keeps your controller or caller code extremely clean:

```ruby
CreateInvoice.execute(amount: 100)
  .on(:success) { |result| redirect_to result.context.invoice }
  .on(:failed)  { |result| render_errors(result.reason) }
  .on(:skipped) { |result| log_skip(result) }
```

You can even combine them. Use `.on(:executed)` to run cleanup logic regardless of success or failure.

### 3. Pattern Matching (Ruby 3.0+)

For complex logic, nothing beats Ruby's pattern matching. CMDx results deconstruct beautifully into both arrays and hashes.

**Array deconstruction** gives you `[state, status]`:

```ruby
case result
in ["complete", "success"]
  # ...
in ["interrupted", "failed"]
  # ...
end
```

**Hash deconstruction** is where the magic happens. You can match against specific metadata or error codes:

```ruby
case result
in { status: "failed", metadata: { code: :insufficient_funds } }
  prompt_to_add_credit_card
in { status: "failed", reason: msg }
  show_generic_error(msg)
in { success: true }
  show_success_confetti
end
```

## Digging Deeper: Chain Analysis

When you're running complex workflows (chains of tasks), a failure might happen deep down in the stack. The top-level result wraps everything, but you can trace the origin.

```ruby
result = ProcessOrderWorkflow.execute(order_id: 123)

if result.failed? && result.caused_failure
  # Who actually blew up?
  culprit = result.caused_failure.task.class.name
  puts "Workflow failed because #{culprit} failed!"
end
```

## Conclusion

By standardizing on a robust `Result` object, CMDx takes the guesswork out of your application's flow. You stop writing defensive checks for `nil` or rescuing generic `StandardError` everywhere. Instead, you get a clear, typed contract for every operation in your system.

So next time you're writing a service object, ask yourself: *What is this actually returning?* If the answer isn't "a consistent Result object," give CMDx a look.
