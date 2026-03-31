# Workflows

Compose multiple tasks into powerful, sequential pipelines. Workflows provide a declarative way to build complex business processes with conditional execution, shared context, and flexible error handling.

Since workflows are Task subclasses, they inherit all Task features: [attributes](https://drexed.github.io/cmdx/attributes/definitions/index.md), [callbacks](https://drexed.github.io/cmdx/callbacks/index.md), [middlewares](https://drexed.github.io/cmdx/middlewares/index.md), [settings](https://drexed.github.io/cmdx/configuration/#task-configuration), and [returns](https://drexed.github.io/cmdx/returns/index.md). Use these to validate workflow-level inputs, set up shared state, or track workflow outcomes.

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  register :middleware, CMDx::Middlewares::Correlate

  before_execution :load_user
  on_failed :notify_admin!

  required :user_id, type: :integer

  returns :onboarded_at

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

Tasks run in declaration order (FIFO), sharing a common context across the pipeline.

Warning

Don't define a `work` method in workflows—the module handles execution automatically. Attempting to do so raises a `RuntimeError`.

### Task

`task` and `tasks` are aliases—use either interchangeably.

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

### Group

Group related tasks to share configuration:

Important

Settings and conditionals apply to all tasks in the group.

```ruby
class ContentModerationWorkflow < CMDx::Task
  include CMDx::Workflow

  # Screening phase
  tasks ScanForProfanity, CheckForSpam, ValidateImages, breakpoints: ["skipped"]

  # Review phase
  tasks ApplyFilters, ScoreContent, FlagSuspicious

  # Decision phase
  tasks PublishContent, QueueForReview, NotifyModerators
end
```

### Conditionals

Conditionals support multiple syntaxes for flexible execution control:

```ruby
class ContentAccessCheck
  def call(task)
    task.context.user.can?(:publish_content)
  end
end

class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  # If and/or Unless
  task SendWelcomeEmail, if: :email_configured?, unless: :email_disabled?

  # Proc
  task SendWelcomeEmail, if: -> { Rails.env.production? && self.class.name.include?("Premium") }

  # Lambda
  task SendWelcomeEmail, if: proc { context.features_enabled? }

  # Class or Module
  task SendWelcomeEmail, unless: ContentAccessCheck

  # Instance
  task SendWelcomeEmail, if: ContentAccessCheck.new

  # Conditional applies to all tasks of this declaration group
  tasks SendWelcomeEmail, CreateDashboard, SetupTutorial, if: :email_configured?

  private

  def email_configured?
    context.user.email_address == true
  end

  def email_disabled?
    context.user.communication_preference == :disabled
  end
end
```

## Halt Behavior

By default, skipped tasks don't stop the workflow—they're treated as no-ops. Configure breakpoints globally via [`workflow_breakpoints`](https://drexed.github.io/cmdx/configuration/#breakpoints) or per-task to customize this behavior.

```ruby
class AnalyticsWorkflow < CMDx::Task
  include CMDx::Workflow

  task CollectMetrics      # If fails → workflow stops
  task FilterOutliers      # If skipped → workflow continues
  task GenerateDashboard   # Only runs if no failures occurred
end
```

### Task Configuration

Configure halt behavior for the entire workflow:

```ruby
class SecurityWorkflow < CMDx::Task
  include CMDx::Workflow

  # Halt on both failed and skipped results
  settings(workflow_breakpoints: ["skipped", "failed"])

  task PerformSecurityScan
  task ValidateSecurityRules
end

class OptionalTasksWorkflow < CMDx::Task
  include CMDx::Workflow

  # Never halt, always continue
  settings(breakpoints: [])

  task TryBackupData
  task TryCleanupLogs
  task TryOptimizeCache
end
```

### Group Configuration

Different task groups can have different halt behavior:

```ruby
class SubscriptionWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateSubscription, ValidatePayment, breakpoints: ["skipped", "failed"]

  # Never halt, always continue
  task SendConfirmationEmail, UpdateBilling, breakpoints: []
end
```

## Rollback in Workflows

Each task in a workflow handles its own rollback independently. When a task's status matches the `rollback_on` setting (default: `["failed"]`), that task's `rollback` method is called immediately after its execution — not retroactively for previously completed tasks.

```ruby
class PaymentWorkflow < CMDx::Task
  include CMDx::Workflow

  task ReserveInventory   # Succeeds → no rollback
  task ChargeCard          # Fails → ChargeCard.rollback called
  task SendConfirmation    # Never runs (workflow halts on failure)
end

class ChargeCard < CMDx::Task
  def work
    context.charge = PaymentGateway.charge(context.amount)
    fail!("Declined") if context.charge.declined?
  end

  def rollback
    PaymentGateway.void(context.charge.id)
  end
end
```

Important

CMDx does **not** automatically rollback previously successful tasks when a later task fails. If you need to undo `ReserveInventory` when `ChargeCard` fails, handle it in `ChargeCard`'s rollback or use a callback on the workflow itself.

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

Build hierarchical workflows by composing workflows within workflows:

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

## Parallel Execution

Run tasks concurrently using native Ruby threads for maximum throughput. No external dependencies required.

```ruby
class SendWelcomeNotifications < CMDx::Task
  include CMDx::Workflow

  # One thread per task (default)
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel

  # Fixed thread pool size
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel, pool_size: 2
end
```

Warning

Each parallel task receives its own context copy, which is merged back after execution. If multiple tasks write to the same key, the last merge wins non-deterministically. Use distinct keys per task to avoid conflicts.

## Task Generator

Generate new CMDx workflow tasks quickly using the built-in generator:

```bash
rails generate cmdx:workflow SendNotifications
```

This creates a new workflow task file with the basic structure:

```ruby
# app/tasks/send_notifications.rb
class SendNotifications < CMDx::Task
  include CMDx::Workflow

  tasks Task1, Task2
end
```

Tip

Use **present tense verbs + pluralized noun** for workflow task names, eg: `SendNotifications`, `DownloadFiles`, `ValidateDocuments`
