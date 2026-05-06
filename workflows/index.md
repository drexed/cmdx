# Workflows

A workflow is a regular `CMDx::Task` that includes `CMDx::Workflow`. You list child tasks; CMDx runs them as a **pipeline** on one shared **context**. Under the hood, `#work` is wired up for you — it hands off to `CMDx::Pipeline`.

Because a workflow is still a task, you keep all the goodies: [inputs](https://drexed.github.io/cmdx/inputs/definitions/index.md), [callbacks](https://drexed.github.io/cmdx/callbacks/index.md), [middlewares](https://drexed.github.io/cmdx/middlewares/index.md), [settings](https://drexed.github.io/cmdx/configuration/#settings), [outputs](https://drexed.github.io/cmdx/outputs/index.md), and [retries](https://drexed.github.io/cmdx/retries/index.md). Use those hooks to validate at the workflow level, warm up shared state, or react when things go sideways.

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

Tasks run in the order you declare them. They all read and write the **same** workflow `context` — think of it as a shared notepad passed down the line.

Warning

Do **not** define your own `#work` on a workflow. The module already owns `#work` and forwards to `Pipeline`. If you override it, CMDx raises `CMDx::ImplementationError` — that is intentional, not a bug.

### `task` / `tasks`

`task` and `tasks` are twins — same thing, pick the name that reads best. Each call adds **one group** to the pipeline (a group can hold one task or many).

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

Every entry must be a `Task` subclass. Pass anything else and you get a `TypeError` **at load time** — nice and early.

### Group options

These knobs apply to the **whole** group you just declared:

| Option                 | Default            | Plain-English meaning                                                                                                                                                                                                                                                                                                                                          |
| ---------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `strategy:`            | `:sequential`      | Run one after another, or `:parallel` at the same time.                                                                                                                                                                                                                                                                                                        |
| `pool_size:`           | `tasks.size`       | How many workers/fibers to use when you pick `:parallel`.                                                                                                                                                                                                                                                                                                      |
| `executor:`            | `:threads`         | What actually runs parallel jobs: `:threads`, `:fibers`, or your own callable. `:fibers` needs a `Fiber.scheduler` (for example inside `Async { ... }`).                                                                                                                                                                                                       |
| `merger:`              | `:last_write_wins` | After parallel siblings finish successfully, how their **copies** of context get folded back into the workflow context: shallow last-wins, `:deep_merge`, `:no_merge`, or your own function.                                                                                                                                                                   |
| `continue_on_failure:` | `false`            | **`false` (default):** sequential stops on first failure; parallel cancels work that has not started yet (in-flight tasks still finish). **`true`:** run every task in the group anyway, then collect failures on the workflow's `errors` (keys look like `:"TaskClass.<input>"` for validation issues and `:"TaskClass.<status>"` for bare `fail!` messages). |
| `if:` / `unless:`      | —                  | Skip the **entire** group when the condition says "nope".                                                                                                                                                                                                                                                                                                      |

### Conditionals

You can gate a group with a symbol (method on the workflow), a proc/lambda, or an object that responds to `call(workflow)`. Pick whatever reads clearest.

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

  # Procs and lambdas run with the workflow as `self`
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

## Halt behavior

**Failed** stops the train. **Skipped** does not — skips are treated like "no-op, keep going."

When something fails, the pipeline copies that task's `reason`, `state`, and `status` up to the workflow with `throw!`, so the workflow's result looks failed too. You can still find the original culprit without scanning: `result.origin`, `result.threw_failure`, and `result.caused_failure` point at the right task.

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

  task CollectMetrics      # Fails → workflow stops, workflow result is failed
  task FilterOutliers      # Skipped → workflow keeps going
  task GenerateDashboard   # Only runs if nothing upstream failed
end
```

Want a "soft" failure that does **not** halt? Use `skip!` with a clear reason instead of `fail!`. There is no magic switch to ignore `fail!` per group — that is by design.

## Rollback in workflows

Picture compensation like undoing a stack of sticky notes.

1. When a task fails, **Runtime** calls that task's `#rollback` (if you defined one) right after `work` returns — **before** the failure is thrown to the workflow.
1. When the whole pipeline gives up, **Pipeline** walks successful tasks in **reverse** run order and calls `#rollback` on any that define it. That is the saga-style cleanup.

Skipped tasks are skipped for rollback too. The task that actually failed was already rolled back by Runtime — Pipeline does not call it twice. If `#rollback` raises, that exception bubbles to **you** — handle it if the domain needs it.

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  task ReserveInventory   # Succeeds → no rollback from Pipeline for this path alone
  task ChargeCard         # Fails    → ChargeCard#rollback runs (Runtime), then pipeline stops
  task SendConfirmation   # Never runs (workflow halted on failure)
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

Compensation across tasks

Put `#rollback` on the task that made the mess — inventory holds, charges, emails, whatever. Reach for a workflow-level `on_failed` only when cleanup does not belong to a single task.

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  task ReserveInventory  # Rolled back second (reverse order) if we unwind
  task ChargeCard        # Rolled back first if it succeeded; Runtime handles it if it failed
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

Parallel groups

Parallel tasks each get a **deep-duplicated** context. Their `#rollback` sees that copy — not the merged workflow context. Keep parallel undo logic self-contained: stash whatever IDs you need on the duplicate during `work`.

## Nested workflows

Workflows are tasks, so nesting is free — drop one workflow inside another.

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

A nested workflow failure bubbles up like any other task failure. The `chain` still records everything — great for debugging and support.

## Parallel execution

Same group, same time — Ruby threads by default. No extra gems required for the stock path.

```ruby
class SendWelcomeNotifications < CMDx::Task
  include CMDx::Workflow

  # One thread per task (default)
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel

  # Bounded thread pool
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush,
        strategy: :parallel, pool_size: 2

  # Default: if one sibling fails, pending siblings are cancelled (started ones still finish)
  tasks ChargeCard, ReserveInventory, EmitAnalytics, strategy: :parallel

  # Batch mode: finish everyone, collect every failure on errors
  tasks ProcessOrder1, ProcessOrder2, ProcessOrder3,
        strategy: :parallel, continue_on_failure: true
end
```

Warning

Each parallel task works on a **copy** of `context`. When successes merge back, order follows **declaration order**, not who finished first — last write to a key wins. Give siblings different keys when you can.

On failure, work that has not started is cancelled; in-flight work still finishes and may merge. With `continue_on_failure: true`, every task runs to completion; failures pile into `workflow.errors` (same key shapes as the table above). The pipeline still stops **after** that group — later groups do not run. The "first" failure for signaling is still declaration order.

### Batch processing with `continue_on_failure`

Use this when you need a report card, not a panic stop — "which rows broke?" instead of "we died on row two."

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

### Executors

Same parallel rules; different **engine**. `:executor` swaps how jobs are scheduled — threads, fibers, or your own pool.

```ruby
# Default — native Ruby threads
tasks A, B, C, strategy: :parallel, executor: :threads

# Fiber scheduler — requires Fiber.scheduler to be installed on the caller
tasks A, B, C, strategy: :parallel, executor: :fibers, pool_size: 10

# Custom callable
tasks A, B, C, strategy: :parallel, executor: MyPool.method(:run)
```

`:fibers` plays nicest when something (often the [`async`](https://github.com/socketry/async) gem) has installed a scheduler:

```ruby
require "async"

Async do
  SendWelcomeNotifications.execute!
end
```

No scheduler? `:fibers` complains at runtime. CMDx itself stays dependency-free.

**Building a custom executor:** anything that responds to `call(jobs:, concurrency:, on_job:)` works. You must call `on_job.call(job)` for each job and block until all finish. The gnarly bits — chain updates, cancellation, merging — stay inside `on_job`; you just decide how to schedule.

Register once, reuse by symbol:

```ruby
class ApplicationTask < CMDx::Task
  register :executor, :bounded_pool, MyPool.method(:run)
end

class ShipItAll < ApplicationTask
  include CMDx::Workflow

  tasks A, B, C, strategy: :parallel, executor: :bounded_pool
end
```

Globally: `CMDx.configuration.executors.register(...)`.

### Merge strategies

After parallel siblings succeed, their context copies fold back into the workflow. Default is shallow last-write-wins in declaration order — fast and predictable until two tasks fight over the same nested key. `:merger` picks the policy up front.

```ruby
# Default — shallow, last declared task wins on conflicts
tasks A, B, C, strategy: :parallel, merger: :last_write_wins

# Recursive hash merge — nested hashes combine instead of replacing wholesale
tasks A, B, C, strategy: :parallel, merger: :deep_merge

# Don't touch the workflow context at all
tasks A, B, C, strategy: :parallel, merger: :no_merge

# Custom — e.g. namespace each sibling's output under its class name
tasks A, B, C, strategy: :parallel,
      merger: ->(ctx, result) { ctx[result.task.name] = result.context.to_h }
```

**Quick mental model:**

- Merging always walks **successful** results in **declaration** order — deterministic even when wall-clock order is not.
- `:deep_merge` only dives into nested `Hash` values. If one side has a string and the other a hash, you still get last-write-wins behavior for that spot.
- `:no_merge` leaves the workflow context alone; you can still inspect each sibling via `result.chain` if you need proof of work.
- A callable gets `(workflow_context, result)` and can write any shape you like. Failed results never reach the merger.
- Named mergers live on `CMDx::Mergers` — `register :merger, :name, callable` on a task or on `CMDx.configuration.mergers`.

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

## Task generator

Scaffold a workflow file:

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

If you do not have `ApplicationTask`, the generator falls back to `CMDx::Task`.

Tip

Name workflows like actions: **present-tense verb + plural noun** — `SendNotifications`, `DownloadFiles`, `ValidateDocuments`. Reads like a button label.
