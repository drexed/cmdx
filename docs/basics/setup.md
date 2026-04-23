# Basics - Setup

Tasks are the unit of work in CMDx: self-contained business logic with built-in input validation, error handling, and execution tracking.

## Structure

Tasks need only two things: inherit from `CMDx::Task` and define a `work` method:

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end
end
```

Without a `work` method, execution raises `CMDx::ImplementationError` from both `execute` and `execute!`.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method defined
end

IncompleteTask.execute  #=> raises CMDx::ImplementationError
IncompleteTask.execute! #=> raises CMDx::ImplementationError
```

## Rollback

Define a `rollback` method to undo side effects when the task fails. Runtime calls it after `work` (and before completion callbacks) when the signal is `failed`, flags `result.rolled_back?`, and emits the `:task_rolled_back` telemetry event.

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

    Rollback fires only on `failed?`. To undo on skip, halt with `fail!` instead of `skip!`, or invoke your cleanup explicitly from a callback.

## Inheritance

Share configuration through inheritance. Every inheritable surface — `settings`, `retry_on`, `deprecation`, and the registries (`middlewares`, `callbacks`, `coercions`, `validators`, `executors`, `mergers`, `telemetry`, `inputs`, `outputs`) — lazily clones from the superclass on first access, so subclasses extend rather than replace.

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

Tasks follow a predictable execution pattern. Halt primitives — `success!`, `skip!`, `fail!`, and `throw!` — are control-flow tokens: they `throw` a `Signal` caught by `Runtime`, so any code after a halt is unreachable. See [Signals](../interruptions/signals.md) for the full halt API and [Getting Started - Task Lifecycle](../getting_started.md#task-lifecycle) for the full flow diagram.

| Stage | Description |
|-------|-------------|
| **Before execution** | `before_execution` callbacks run first |
| **Before validation** | `before_validation` callbacks run next |
| **Validation** | Inputs are coerced/validated; failures halt with `failed` |
| **Work** | `work` runs inside `catch(:cmdx_signal)`, wrapped in retries |
| **Output verification** | Declared `output` keys are checked on `context` when `work` returned without halting; `:default` fills nils, missing keys fail the task. Skipped when `work` halts via `success!` / `skip!` / `fail!` / `throw!` |
| **Rollback** | `rollback` runs when the signal is `failed` (before completion callbacks) |
| **Completion callbacks** | `on_<state>`, `on_<status>`, `on_ok`/`on_ko` fire in that order |
| **Result finalization** | `Result` built and added to `Chain` (root is `unshift`ed; children are `push`ed) |
| **Teardown** | Task, root context, errors, and chain are frozen; chain reference cleared from the fiber |

!!! danger "Caution"

    Tasks are single-use objects. After execution, the task, its root context, and its errors are frozen by `Runtime` teardown.
