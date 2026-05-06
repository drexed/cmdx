# Basics - Setup

Hey there. In CMDx, a **task** is just a tidy box for one piece of business logic. You get input checks, errors that behave predictably, and a clear story of what ran — without building all of that wiring by hand.

## Structure

Every task needs two things: inherit from `CMDx::Task` and implement `work`. That’s it.

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end
end
```

If you skip `work`, CMDx doesn’t know what to run. Both `execute` and `execute!` raise `CMDx::ImplementationError` in that case — a friendly nudge to finish the job.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method defined
end

IncompleteTask.execute  #=> raises CMDx::ImplementationError
IncompleteTask.execute! #=> raises CMDx::ImplementationError
```

## Rollback

Sometimes `work` does real-world stuff you need to undo if things go wrong (charges, locks, temp files). Add a `rollback` method for that. CMDx calls it **after** `work` when the outcome is a real failure — before the “we’re done” callbacks — sets a flag on the result, and emits a `:task_rolled_back` telemetry ping so you can see it in your dashboards.

```ruby
class ChargeCard < CMDx::Task
  def work
    context.charge = Stripe::Charge.create(amount: context.amount, source: context.source)
  end

  # Called automatically when this task fails
  def rollback
    Stripe::Refund.create(charge: context.charge.id) if context.charge
  end
end
```

!!! tip

    Rollback only runs when the task **failed**. If you skipped on purpose, rollback won’t fire. Need cleanup on skip? Either fail with `fail!` instead of `skip!`, or run your cleanup from a callback you control.

## Inheritance

Got shared behavior? Put it on a base class. Subclasses **inherit** settings instead of starting from zero: things like `settings`, `retry_on`, `deprecation`, and the big registries (`middlewares`, `callbacks`, `coercions`, `validators`, `executors`, `mergers`, `telemetry`, `inputs`, `outputs`) are copied lazily from the parent the first time the child touches them — so you **add** on top, you don’t accidentally wipe the parent’s config.

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, SecurityMiddleware.new

  before_execution :initialize_request_tracking

  input :session_id

  private

  def initialize_request_tracking
    context.tracking_id ||= SecureRandom.uuid
  end
end

class SyncInventory < ApplicationTask
  def work
    # Your logic here...
  end
end
```

## Lifecycle

Tasks run in the same order every time — easy to reason about. The “halt” helpers (`success!`, `skip!`, `fail!`, `throw!`) are special: they **stop** the current path by throwing a `Signal` that the runtime catches. Anything after a halt in `work` won’t run. For the full menu, see [Signals](../interruptions/signals.md); for a picture of the whole flow, see [Getting Started - Task Lifecycle](../getting_started.md#task-lifecycle).

| Stage | In plain English |
|-------|------------------|
| **Before execution** | `before_execution` hooks run first — warm-up time. |
| **Before validation** | `before_validation` hooks run next — last chance before inputs are checked. |
| **Around execution** | `around_execution` wraps `work` (and `rollback` if it runs). Each hook must `yield` **once**. Several hooks nest like onions: outer declared first runs outermost. |
| **Validation** | Inputs get coerced and validated. Bad input → failed halt. |
| **Work** | Your `work` runs, inside retry logic and a `catch` for signals. |
| **Output verification** | If you declared `output` keys, CMDx checks they’re on `context` when `work` returns normally. `:default` can fill nils; missing keys fail the task. Skipped if you halted with `success!` / `skip!` / `fail!` / `throw!`. |
| **Rollback** | If we failed, `rollback` runs before the completion party. |
| **After execution** | `after_execution` runs after the around-block finishes. |
| **Completion callbacks** | `on_<state>`, `on_<status>`, then `on_ok` / `on_ko` — in that order. |
| **Result finalization** | Build the `Result` and attach it to the `Chain` (root goes in front; children append). |
| **Teardown** | Freeze task, root context, errors, and chain; clear the chain off the fiber. We’re done. |

!!! danger "Caution"

    One task instance, one ride. After execution, the runtime **freezes** the task, its root context, and its errors. Don’t reuse that object for another run — make a fresh instance.
