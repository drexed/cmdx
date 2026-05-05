# Interruptions - Exceptions

CMDx defines a small, flat exception hierarchy. Every exception the framework raises descends from `CMDx::Error`, so a single `rescue CMDx::Error` catches everything without trapping unrelated `StandardError`s. How they surface depends on whether you call `execute` (safe) or `execute!` (strict).

Important

Prefer `skip!` and `fail!` over raising exceptions — they signal intent more clearly and carry structured `reason`/`metadata`. See [Signals](https://drexed.github.io/cmdx/interruptions/signals/index.md).

## Hierarchy

```text
StandardError
└── CMDx::Error  (alias: CMDx::Exception)
    ├── CMDx::CallbackError
    ├── CMDx::DefinitionError
    ├── CMDx::DeprecationError
    ├── CMDx::ImplementationError
    ├── CMDx::MiddlewareError
    └── CMDx::Fault
```

Note

`execute!` only raises `Fault` on `failed?` results — skipped results return normally. Coercion and validation errors do **not** raise; they accumulate on `task.errors` and surface as a failed result (a `Fault` under `execute!`).

## Exception Types

### CMDx::Error

Base class for every CMDx exception. Aliased as `CMDx::Exception`.

```ruby
begin
  ProcessOrder.execute!(order_id: 42)
rescue CMDx::Error => e
  # Catches every CMDx-raised exception
end
```

### CMDx::DefinitionError

Raised at class-load time when a declaration is structurally invalid:

- An input name clashes with an existing accessor on the task (e.g. `:context`, `:errors`, or any user-defined method).
- A workflow `task` / `tasks` declaration is called with options but no tasks.

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

Raised by [`deprecation :error`](https://drexed.github.io/cmdx/deprecation/index.md) when a class marked as prohibited is executed.

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

Raised when a subclass fails its abstract contract:

| Trigger                                   | When it's raised                        | Message                                    |
| ----------------------------------------- | --------------------------------------- | ------------------------------------------ |
| Defining `#work` on a `Workflow`          | at class-load time (via `method_added`) | `cannot define <Class>#work in a workflow` |
| Calling `Task#work` without overriding it | inside `work` at execution time         | `undefined method <Class>#work`            |

```ruby
class IncompleteTask < CMDx::Task
  # no #work defined
end

IncompleteTask.execute  #=> raises CMDx::ImplementationError
IncompleteTask.execute! #=> raises CMDx::ImplementationError
```

### CMDx::CallbackError

Raised when an `around_execution` callback fails to invoke its continuation. Without this guard, a buggy around callback would silently bypass the task body.

```ruby
class ForgetfulCallback < CMDx::Task
  around_execution proc { |task, _cont| log("started") }  # never calls cont

  def work; end
end

ForgetfulCallback.execute!
#=> raises CMDx::CallbackError: "around_execution callback did not invoke its continuation"
```

### CMDx::MiddlewareError

Raised by the middleware chain when a registered middleware forgets to yield to `next_link`. Without this guard, a buggy middleware would silently bypass the task body.

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

Important

Always `yield` (or call `next_link.call`) inside your middleware — `MiddlewareError` is raised outside the signal `catch` and propagates from both `execute` and `execute!`.

### CMDx::Fault

The only exception raised by `execute!` on `failed?` results. `Fault` carries the **originating** failed [`Result`](https://drexed.github.io/cmdx/outcomes/result/index.md) and delegates `task`, `context`, and `chain` to it. For workflows, the originating result is the deepest leaf that failed — not the workflow itself — so matchers like `Fault.for?(LeafTask)` work uniformly across flat and nested executions.

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

`Runtime#perform_work` rescues in a strict order: `Fault` (echoes) → `CMDx::Error` (**re-raises**, never converts to a failed result) → `StandardError` (converts to a failed result with `cause` set). `execute!` then re-raises: if `result.cause` holds a captured exception, the **original** exception bubbles up; otherwise a `CMDx::Fault` wrapping the failed result is raised.

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

| Trigger                                                                                                                  | `execute` (safe)              | `execute!` (strict)                  |
| ------------------------------------------------------------------------------------------------------------------------ | ----------------------------- | ------------------------------------ |
| `success!`                                                                                                               | success result                | success result                       |
| `skip!`                                                                                                                  | skipped result                | skipped result (no raise)            |
| `fail!`                                                                                                                  | failed result                 | raises `Fault`                       |
| `throw!(failed_result)`                                                                                                  | failed result                 | raises `Fault`                       |
| Coercion / validation error on input                                                                                     | failed result                 | raises `Fault`                       |
| Non-framework `StandardError` inside `work`                                                                              | failed result with `cause`    | re-raises the **original** exception |
| Any `CMDx::Error` subclass inside `work` (`ImplementationError`, `DeprecationError`, `MiddlewareError`, `CallbackError`) | propagates                    | propagates                           |
| `ImplementationError` from `Workflow.method_added`                                                                       | propagates at class-load time | propagates at class-load time        |
| `DefinitionError` from a conflicting input declaration                                                                   | propagates at class-load time | propagates at class-load time        |
| Non-`StandardError` (e.g. `Interrupt`, `SignalException`)                                                                | propagates                    | propagates                           |

See [Faults](https://drexed.github.io/cmdx/interruptions/faults/index.md) for `Fault.for?` / `Fault.matches?` matchers.

## Backtrace Cleaning

`Fault` backtraces are passed through the configured `backtrace_cleaner` (set on `CMDx.configuration.backtrace_cleaner` or per-task via `settings`). This is useful for stripping framework frames in Rails apps:

```ruby
CMDx.configure do |config|
  config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
end
```
