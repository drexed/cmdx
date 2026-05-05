# Workflows

Compose multiple tasks into ordered pipelines. A workflow is a `Task` subclass that includes `CMDx::Workflow`; the module supplies a `#work` that delegates to `CMDx::Pipeline`, which runs the declared task groups against a shared context.

Because workflows are tasks, they inherit every Task feature: [inputs](inputs/definitions.md), [callbacks](callbacks.md), [middlewares](middlewares.md), [settings](configuration.md#settings), [outputs](outputs.md), and [retries](retries.md). Use these to validate workflow-level inputs, set up shared state, or react to workflow outcomes.

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  before_execution :load_user
  on_failed :notify_admin!

  required :user_id, coerce: :integer

  output :onboarded_at

  task CreateProfile
  task SetupPreferences
  task SendWelcome

  private

  def load_user
    context.user = User.find(user_id)
  end

  def notify_admin!
    AdminMailer.onboarding_failed(context.user).deliver_later
  end
end
```

## Declarations

Tasks run in declaration order, sharing the workflow's context.

!!! warning

    Don't define `#work` on a workflow — `Workflow#work` delegates to `Pipeline`. Defining your own raises `CMDx::ImplementationError`.

### Task

`task` and `tasks` are aliases — use either interchangeably. Each call appends a new group to the pipeline.

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

Every entry must be a `Task` subclass; anything else raises `TypeError` at declaration time.

### Group Options

Options apply to the entire group:

| Option        | Default        | Description                                            |
|---------------|----------------|--------------------------------------------------------|
| `strategy:`   | `:sequential`  | `:sequential` or `:parallel`                           |
| `pool_size:`  | `tasks.size`   | Worker/fiber count when `strategy: :parallel`          |
| `executor:`   | `:threads`     | Parallel dispatch backend: `:threads`, `:fibers`, or a callable. `:fibers` requires a `Fiber.scheduler` to be installed (e.g. inside `Async { ... }`) |
| `merger:` | `:last_write_wins` | How successful parallel contexts fold back into the workflow context: `:last_write_wins`, `:deep_merge`, `:no_merge`, or a callable `->(workflow_context, result) { ... }` |
| `continue_on_failure:` | `false` | When `true`, run every task in the group to completion even after a failure, and aggregate all failures into the workflow's `errors` (keyed as the Symbol `:"TaskClass.<input>"` for input/validation errors and `:"TaskClass.<status>"` for bare `fail!` reasons). Applies to both strategies. When `false` (default), `:sequential` halts on the first failure and `:parallel` cancels pending tasks (in-flight tasks still finish) |
| `if:` / `unless:` | —          | Skip the entire group when the predicate isn't satisfied |

### Conditionals

Conditionals support multiple syntaxes for flexible execution control. They're evaluated against the workflow instance.

```ruby
class ContentAccessCheck
  def call(workflow)
    workflow.context.user.can?(:publish_content)
  end
end

class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  # Symbols resolve to instance methods on the workflow
  task SendWelcomeEmail, if: :email_configured?

  # Procs and lambdas are instance_exec'd against the workflow
  task SendWelcomeEmail, if: -> { Rails.env.production? }
  task SendWelcomeEmail, if: proc { context.features_enabled? }

  # Class or instance: must respond to #call(workflow)
  task SendWelcomeEmail, unless: ContentAccessCheck
  task SendWelcomeEmail, if: ContentAccessCheck.new

  # The conditional applies to every task in the group
  tasks SendWelcomeEmail, CreateDashboard, SetupTutorial, if: :email_configured?

  private

  def email_configured?
    context.user.email_address.matches?(/@mycompany.com/)
  end
end
```

## Halt Behavior

A workflow halts on the **first failed result** in any group. Skipped tasks never halt the pipeline — they're treated as no-ops and the next task runs as normal.

When a task fails, the pipeline echoes its `reason`, `state`, and `status` through the workflow via `throw!`, so the workflow's own result is `failed?` with the same `reason`. The propagated signal carries the failed leaf as its `origin`, so `result.origin` / `result.threw_failure` / `result.caused_failure` all point at the originating task without scanning the chain:

```ruby
result = AnalyticsWorkflow.execute

result.failed?                  #=> true
result.reason                   #=> "metrics service unreachable"
result.origin.task              #=> CollectMetrics
result.caused_failure.task      #=> CollectMetrics
```

```ruby
class AnalyticsWorkflow < CMDx::Task
  include CMDx::Workflow

  task CollectMetrics      # If fails → workflow stops, AnalyticsWorkflow is failed
  task FilterOutliers      # If skipped → workflow continues
  task GenerateDashboard   # Only runs if no upstream failure occurred
end
```

To make a "soft" failure non-halting, have the task `skip!` instead of `fail!`. There is no per-group or per-workflow setting to ignore failures.

## Rollback in Workflows

When a task fails, Runtime calls its `#rollback` method (if defined) immediately after `work` returns and *before* the failure is `throw!`n up to the workflow. Concretely, the failed leaf task's lifecycle is: `perform_work` → `perform_rollback` → `on_*` callbacks → result finalization → throw to workflow.

When a workflow's pipeline halts, `Pipeline` then walks every previously executed task instance whose result is `success?` in **reverse** execution order and invokes `#rollback` on any that defines it — saga-style compensation across the whole pipeline. Each compensated result's `#rolled_back?` becomes `true`. Skipped tasks are excluded; the failing task itself is rolled back by Runtime and is not re-invoked. Exceptions raised inside a compensator propagate to the caller — handling them is the developer's responsibility.

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  task ReserveInventory   # Succeeds → no rollback
  task ChargeCard         # Fails    → ChargeCard#rollback runs
  task SendConfirmation   # Never runs (workflow halts on failure)
end

class ChargeCard < CMDx::Task
  def work
    context.charge = PaymentGateway.charge(context.amount)
    fail!("Declined") if context.charge.declined?
  end

  def rollback
    PaymentGateway.void(context.charge.id) if context.charge
  end
end
```

!!! note "Compensation across tasks"

    Pipeline rollback covers the common saga case automatically: define `#rollback` on each task that has side effects to undo, and the workflow will compensate them in reverse order on failure. Use a workflow-level `on_failed` callback only when compensation logic doesn't belong to any single task (e.g. it spans multiple contexts or external systems).

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  task ReserveInventory  # rolled back second on failure (in reverse)
  task ChargeCard        # rolled back first if it succeeded; Runtime rolls it back if it failed
  task SendConfirmation
end

class ReserveInventory < CMDx::Task
  def work
    context.reservation_id = Inventory.reserve(context.sku, context.qty)
  end

  def rollback
    Inventory.release(context.reservation_id)
  end
end
```

!!! warning "Parallel groups"

    Tasks in a `:parallel` group run on a `deep_dup`'d context. Their `#rollback` sees that per-task copy, not the merged workflow context. Keep parallel compensators self-contained (e.g. external API calls keyed off values captured during `work`) rather than relying on shared workflow state.

## Nested Workflows

Workflows are tasks, so they nest naturally:

```ruby
class EmailPreparationWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateRecipients
  task CompileTemplate
end

class EmailDeliveryWorkflow < CMDx::Task
  include CMDx::Workflow

  tasks SendEmails, TrackDeliveries
end

class CompleteEmailWorkflow < CMDx::Task
  include CMDx::Workflow

  task EmailPreparationWorkflow
  task EmailDeliveryWorkflow, if: proc { context.preparation_successful? }
  task GenerateDeliveryReport
end
```

A nested workflow's failure echoes through its parent the same way a leaf task's failure does, and the chain captures every result for traceability.

## Parallel Execution

Run a group concurrently using native Ruby threads. No external dependencies required.

```ruby
class SendWelcomeNotifications < CMDx::Task
  include CMDx::Workflow

  # One thread per task (default)
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel

  # Bounded thread pool
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush,
        strategy: :parallel, pool_size: 2

  # Default behavior: pending parallel tasks are cancelled once any sibling fails
  tasks ChargeCard, ReserveInventory, EmitAnalytics, strategy: :parallel

  # Batch processing: run every task and collect every failure into result.errors
  tasks ProcessOrder1, ProcessOrder2, ProcessOrder3,
        strategy: :parallel, continue_on_failure: true
end
```

!!! warning

    Each parallel task receives its own deep-duplicated `context` copy, which is merged back into the workflow's context after execution (declaration order, not completion order). If multiple tasks write to the same key, the last task in declaration order wins. Use distinct keys per task to avoid conflicts. By default, when any parallel task fails, pending tasks are cancelled (in-flight tasks still finish and successful contexts still merge) and the failed result is propagated through `throw!`. With `continue_on_failure: true`, every task runs to completion and all failures are aggregated into the workflow's `errors` (keyed as Symbols: `:"TaskClass.<input>"` for validation errors or `:"TaskClass.<status>"` for bare `fail!` reasons); the first failure in declaration order is still the one propagated through `throw!`.

### Batch processing with `continue_on_failure`

For batch-style groups where you want to know about every failure rather than stopping at the first one, set `continue_on_failure: true`. Failures are aggregated into the workflow's `errors` collection.

```ruby
class ProcessOrders < CMDx::Task
  include CMDx::Workflow

  tasks ProcessOrderA, ProcessOrderB, ProcessOrderC, continue_on_failure: true
end

result = ProcessOrders.execute
result.failed?           # => true (any task in the group failed)
result.errors.to_h
# => {
#      :"ProcessOrderA.failed" => ["card declined"],
#      :"ProcessOrderC.amount" => ["amount must be greater than 0"]
#    }
```

The pipeline still halts after the failed group — subsequent groups do not run. The first failure (declaration order) is the signal origin.

### Executors

The `:executor` option swaps the concurrency backend while keeping the rest of the parallel semantics (context isolation, merge-on-success, fail-fast) identical.

```ruby
# Default — native Ruby threads
tasks A, B, C, strategy: :parallel, executor: :threads

# Fiber scheduler — requires Fiber.scheduler to be installed on the caller
tasks A, B, C, strategy: :parallel, executor: :fibers, pool_size: 10

# Custom callable
tasks A, B, C, strategy: :parallel, executor: MyPool.method(:run)
```

`:fibers` spawns one fiber per job bounded by `pool_size` (via a semaphore) and relies on whatever scheduler the caller has installed — most commonly the [`async`](https://github.com/socketry/async) gem:

```ruby
require "async"

Async do
  SendWelcomeNotifications.execute!
end
```

Without a scheduler, `:fibers` raises at run time — the gem itself stays zero-dep.

A user-supplied executor is any object responding to `call(jobs:, concurrency:, on_job:)`. It must invoke `on_job.call(job)` for each job and block until all jobs have completed. Chain propagation, cancellation, and context merging are already baked into `on_job`; the executor only decides how to dispatch.

Executors are resolved from a per-task registry (`CMDx::Executors`). Built-ins ship with `:threads` and `:fibers`; register your own named executor once and reference it by symbol from `:executor`:

```ruby
class ApplicationTask < CMDx::Task
  register :executor, :bounded_pool, MyPool.method(:run)
end

class ShipItAll < ApplicationTask
  include CMDx::Workflow

  tasks A, B, C, strategy: :parallel, executor: :bounded_pool
end
```

The same registry is available globally via `CMDx.configuration.executors.register(...)`.

### Merge strategies

After every successful sibling completes, each sibling's duplicated context is folded back into the workflow context. The default is last-write-wins in declaration order — reliable and fast, but brittle when two tasks write a nested structure under the same key. `:merger` lets you pick the collision policy up front.

```ruby
# Default — shallow, last declared task wins on conflicts
tasks A, B, C, strategy: :parallel, merger: :last_write_wins

# Recursive hash merge — nested structures are combined instead of replaced
tasks A, B, C, strategy: :parallel, merger: :deep_merge

# Don't touch the workflow context at all
tasks A, B, C, strategy: :parallel, merger: :no_merge

# Custom — e.g. namespace each sibling's output under its class name
tasks A, B, C, strategy: :parallel,
      merger: ->(ctx, result) { ctx[result.task.name] = result.context.to_h }
```

Behavior notes:

- Merging always walks successful results in **declaration order**, never completion order — the fold is deterministic even though parallel execution isn't.
- `:deep_merge` recurses only into `Hash` values; non-hash collisions (Integer, String, Array, custom objects) still follow last-write-wins so a scalar on either side wins over a hash on the other.
- `:no_merge` keeps the parallel tasks' side effects (each sibling's `result.context` is still reachable via `result.chain`) but nothing is written back to the workflow context. Useful when you're only interested in per-task telemetry, or when tasks own their own persistence.
- A callable receives `(workflow_context, result)` and is free to write whatever shape you want. Failed results never reach the merger.
- Merge strategies are resolved from a per-task registry (`CMDx::Mergers`). Register your own named merger with `register :merger, :name, callable` (or on `CMDx.configuration.mergers`) and reference it by symbol from `:merger`.

```ruby
class BuildDashboard < CMDx::Task
  include CMDx::Workflow

  tasks FetchRevenue, FetchTraffic, FetchErrors,
        strategy: :parallel, merger: :deep_merge
  # FetchRevenue: context.metrics = { revenue: ... }
  # FetchTraffic: context.metrics = { visitors: ... }
  # After merge: context.metrics == { revenue: ..., visitors: ..., errors: ... }
end
```

## Task Generator

Generate a workflow scaffold:

```bash
rails generate cmdx:workflow SendNotifications
```

Produces:

```ruby
# app/tasks/send_notifications.rb
class SendNotifications < ApplicationTask
  include CMDx::Workflow

  # Docs: https://drexed.github.io/cmdx/workflows
end
```

If `ApplicationTask` isn't defined the generator falls back to `CMDx::Task`.

!!! tip

    Use **present-tense verb + pluralized noun** for workflow names: `SendNotifications`, `DownloadFiles`, `ValidateDocuments`.
