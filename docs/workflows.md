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
| `pool_size:`  | `tasks.size`   | Worker count when `strategy: :parallel`                |
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

When a task fails, Runtime calls its `#rollback` method (if defined) immediately after `work` returns and *before* the failure is `throw!`n up to the workflow. Concretely, the failed leaf task's lifecycle is: `perform_work` → `perform_rollback` → `on_*` callbacks → result finalization → throw to workflow. Rollback is **per-task**: previously successful tasks in the same workflow are not rolled back automatically.

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

!!! warning "Compensation across tasks"

    To undo earlier successful tasks when a later one fails, handle it on the workflow itself with an `on_failed` callback. The callback runs after the pipeline halts but before teardown, with full access to `context`.

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  on_failed :compensate!

  task ReserveInventory
  task ChargeCard

  private

  def compensate!
    ReleaseInventory.execute(context) if context.reservation_id
  end
end
```

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
end
```

!!! warning

    Each parallel task receives its own deep-duplicated `context` copy, which is merged back into the workflow's context after execution. If multiple tasks write to the same key, the last merge wins non-deterministically. Use distinct keys per task to avoid conflicts. If any parallel task fails, the failed result is propagated through `throw!` (the other tasks still complete first; they just don't merge back).

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
