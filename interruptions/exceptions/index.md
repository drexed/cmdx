# Interruptions - Exceptions

CMDx keeps its exceptions in a small, flat family tree. Everything the framework raises inherits from `CMDx::Error`, so one `rescue CMDx::Error` can catch CMDx problems without swallowing random app errors.

Whether you see an exception or a `Result` depends on how you call the task: `execute` is the safe path, `execute!` is the strict one.

Prefer signals inside work

Inside `work`, reach for `skip!` and `fail!` before you `raise`. They spell out intent and carry `reason` and `metadata` in a way exceptions usually do not. See [Signals](https://drexed.github.io/cmdx/interruptions/signals/index.md).

## Hierarchy

```text
StandardError
└── CMDx::Error  (alias: CMDx::Exception)
    ├── CMDx::CallbackError
    ├── CMDx::DefinitionError
    ├── CMDx::DeprecationError
    ├── CMDx::FrozenTaskError
    ├── CMDx::ImplementationError
    ├── CMDx::MiddlewareError
    ├── CMDx::UnknownAccessorError
    ├── CMDx::UnknownEntryError
    ├── CMDx::UnknownLocaleError
    └── CMDx::Fault
```

Note

`execute!` raises `Fault` only for failed results. Skips return normally. Bad coercion or validation does not raise during the happy path — those issues collect on `task.errors` and show up as a failed result (and thus a `Fault` under `execute!`).

## Exception Types

### CMDx::Error

The umbrella type for "this came from CMDx." Also aliased as `CMDx::Exception`.

```ruby
begin
  ProcessOrder.execute!(order_id: 42)
rescue CMDx::Error => e
  # Catches every CMDx-raised exception
end
```

### CMDx::DefinitionError

The framework raises this while your class file loads if a declaration does not make sense:

- An input name fights with something already on the task (for example `:context`, `:errors`, or a method you defined).
- A workflow calls `task` / `tasks` with options but no actual tasks.

```ruby
class ConflictingTask < CMDx::Task
  required :context  #=> raises CMDx::DefinitionError
  # "cannot define input :context: #context is already defined on ConflictingTask"
end

class EmptyGroupWorkflow < CMDx::Task
  include CMDx::Workflow
  tasks strategy: :parallel  #=> raises CMDx::DefinitionError
  # "EmptyGroupWorkflow: cannot declare an empty task group"
end
```

### CMDx::DeprecationError

Shows up when you marked a class with `deprecation :error` and someone still runs it.

```ruby
class LegacyTask < CMDx::Task
  deprecation :error

  def work
    # never executes
  end
end

begin
  LegacyTask.execute!
rescue CMDx::DeprecationError => e
  e.message #=> "LegacyTask usage prohibited"
end
```

### CMDx::ImplementationError

"You forgot to finish the homework." Raised when a subclass breaks the abstract rules:

| Trigger                                    | When it's raised                        | Message                                    |
| ------------------------------------------ | --------------------------------------- | ------------------------------------------ |
| You define `#work` on a `Workflow`         | at class-load time (via `method_added`) | `cannot define <Class>#work in a workflow` |
| You call `Task#work` without overriding it | inside `work` at run time               | `undefined method <Class>#work`            |

```ruby
class IncompleteTask < CMDx::Task
  # no #work defined
end

IncompleteTask.execute  #=> raises CMDx::ImplementationError
IncompleteTask.execute! #=> raises CMDx::ImplementationError
```

### CMDx::CallbackError

Raised when an `around_execution` callback never calls its continuation. Without this, a buggy callback could skip the task body and nobody would notice.

```ruby
class ForgetfulCallback < CMDx::Task
  around_execution proc { |task, _cont| log("started") }  # never calls cont

  def work; end
end

ForgetfulCallback.execute!
#=> raises CMDx::CallbackError: "around_execution callback did not invoke its continuation"
```

### CMDx::FrozenTaskError

Raised when `success!`, `skip!`, `fail!`, or `throw!` is called on a task that has already completed and been frozen. Halts only make sense **inside** `work` while Runtime's signal `catch` is active.

```ruby
class LateHalter < CMDx::Task
  def work; end
end

task = LateHalter.new
task.execute
task.send(:fail!, "too late") #=> raises CMDx::FrozenTaskError: "cannot call :fail! after the task has been frozen"
```

### CMDx::UnknownAccessorError

Raised by [`Context`](https://drexed.github.io/cmdx/basics/context/index.md) in **strict mode** when reading a key that was never assigned. Replaces the bare `NoMethodError` so you can rescue framework typos without catching unrelated `NoMethodError`s.

```ruby
class StrictTask < CMDx::Task
  settings(strict_context: true)

  def work
    context.typoed_key #=> raises CMDx::UnknownAccessorError: "unknown context key :typoed_key (strict mode)"
  end
end
```

### CMDx::UnknownEntryError

Raised when a registry lookup is performed against a name that has not been registered — coercions, validators, executors, mergers, retriers, deprecators, and telemetry events all funnel through this single type.

```ruby
class BadCoercion < CMDx::Task
  required :amount, coerce: :doubloon

  def work; end
end

BadCoercion.execute!(amount: "10")
#=> raises CMDx::UnknownEntryError: "unknown coercion: doubloon"

CMDx.configuration.telemetry.unsubscribe(:bogus_event, ->{})
#=> raises CMDx::UnknownEntryError: "unknown event :bogus_event, must be one of ..."
```

### CMDx::UnknownLocaleError

Raised when CMDx is running **without** the `i18n` gem and `default_locale` cannot be resolved to a YAML file on the locale load path. See [Internationalization](https://drexed.github.io/cmdx/internationalization/index.md).

```ruby
CMDx.configure { |c| c.default_locale = "xx" }
ProcessQuote.execute(price: "invalid")
#=> raises CMDx::UnknownLocaleError: "unable to load xx translations"
```

### CMDx::MiddlewareError

Same idea as callbacks, but for middleware: something in the chain forgot to yield to `next_link`.

```ruby
class BrokenMiddleware
  def call(task)
    # forgot to yield
  end
end

class MyTask < CMDx::Task
  register :middleware, BrokenMiddleware
  def work; end
end

MyTask.execute!
#=> raises CMDx::MiddlewareError: "middleware did not yield the next_link"
```

Middleware escapes the signal catch

Always `yield` (or call `next_link.call`) in middleware. `MiddlewareError` is raised outside the signal handler, so it bubbles out of both `execute` and `execute!`.

### CMDx::Fault

The one exception `execute!` raises for a failed task result. A `Fault` holds the **originating** failed [`Result`](https://drexed.github.io/cmdx/outcomes/result/index.md) and forwards `task`, `context`, and `chain` from it. In workflows the "origin" is the deepest leaf that failed, not the outer workflow — so `Fault.for?(LeafTask)` works the same for flat runs and nested ones.

```ruby
begin
  ProcessOrder.execute!(order_id: 42)
rescue CMDx::Fault => e
  e.task              #=> ProcessOrder            (the task class, not an instance)
  e.result            #=> the failed Result that originated the failure
  e.result.state      #=> "interrupted"
  e.result.status     #=> "failed"
  e.result.reason     #=> "payment declined"
  e.result.metadata   #=> { code: "INSUFFICIENT_FUNDS" }
  e.result.cause      #=> the underlying exception when one was rescued (or nil)
  e.result.origin     #=> the upstream result this signal was echoed from
  e.context           #=> the failing task's frozen context
  e.chain             #=> the full Chain of Results from the run
  e.message           #=> I18nProxy.tr(e.result.reason) — translated when the reason is an i18n key, otherwise passes through verbatim; falls back to the localized "unspecified" string when reason is nil
  e.backtrace         #=> cleaned via the task's `backtrace_cleaner` setting when configured
end
```

## Execute vs Execute!

Think of the runtime as a traffic cop with a fixed order of operations:

1. `Fault` echoes get handled as failures.
1. Any other `CMDx::Error` is **re-raised** — it never becomes a failed result.
1. A normal `StandardError` becomes a failed result with `cause` set.

After that, `execute!` decides what to raise: if `result.cause` holds a captured exception, you see that **original** exception again. Otherwise you get a `CMDx::Fault` wrapping the failed result.

```ruby
class CompressDocument < CMDx::Task
  def work
    document = Document.find(context.document_id)
    document.compress!
  end
end

CompressDocument.execute(document_id: "unknown-doc-id").then do |r|
  r.failed? #=> true
  r.reason  #=> "[ActiveRecord::RecordNotFound] Couldn't find Document with 'id'=unknown-doc-id"
  r.cause   #=> #<ActiveRecord::RecordNotFound>
end

begin
  CompressDocument.execute!(document_id: "unknown-doc-id")
rescue ActiveRecord::RecordNotFound => e
  puts "Handle exception: #{e.message}"
end
```

| Trigger                                                                                                                                                                                                        | `execute` (safe)              | `execute!` (strict)                  |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------ |
| `success!`                                                                                                                                                                                                     | success result                | success result                       |
| `skip!`                                                                                                                                                                                                        | skipped result                | skipped result (no raise)            |
| `fail!`                                                                                                                                                                                                        | failed result                 | raises `Fault`                       |
| `throw!(failed_result)`                                                                                                                                                                                        | failed result                 | raises `Fault`                       |
| Coercion / validation error on input                                                                                                                                                                           | failed result                 | raises `Fault`                       |
| Non-framework `StandardError` inside `work`                                                                                                                                                                    | failed result with `cause`    | re-raises the **original** exception |
| Any `CMDx::Error` subclass inside `work` (`ImplementationError`, `DeprecationError`, `MiddlewareError`, `CallbackError`, `FrozenTaskError`, `UnknownAccessorError`, `UnknownEntryError`, `UnknownLocaleError`) | propagates                    | propagates                           |
| `ImplementationError` from `Workflow.method_added`                                                                                                                                                             | propagates at class-load time | propagates at class-load time        |
| `DefinitionError` from a conflicting input declaration                                                                                                                                                         | propagates at class-load time | propagates at class-load time        |
| Non-`StandardError` (e.g. `Interrupt`, `SignalException`)                                                                                                                                                      | propagates                    | propagates                           |

For matching faults in `rescue` clauses, see [Faults](https://drexed.github.io/cmdx/interruptions/faults/index.md).

## Backtrace Cleaning

`Fault` backtraces can pass through a `backtrace_cleaner` (global on `CMDx.configuration` or per-task in `settings`). Rails apps often wire this to strip framework noise:

```ruby
CMDx.configure do |config|
  config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
end
```
