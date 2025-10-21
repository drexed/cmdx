# Workflows

Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business logic from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

## Declarations

Tasks execute sequentially in declaration order (FIFO). The workflow context propagates to each task, allowing access to data from previous executions.

> [!IMPORTANT]
> Do **NOT** define a `work` method in workflow tasks. The included module automatically provides the execution logic.

### Task

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

> [!TIP]
> Execute tasks in parallel via the [cmdx-parallel](https://github.com/drexed/cmdx-parallel) gem.

### Group

Group related tasks for better organization and shared configuration:

> [!IMPORTANT]
> Settings and conditionals for a group apply to all tasks within that group.

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

By default skipped tasks are considered no-op executions and does not stop workflow execution.
This is configurable via global and task level breakpoint settings. Task and group configurations
can be used together within a workflow.

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

  task CreateSubscription, ValidatePayment, workflow_breakpoints: ["skipped", "failed"]

  # Never halt, always continue
  task SendConfirmationEmail, UpdateBilling, breakpoints: []
end
```

## Nested Workflows

Workflows can task other workflows for hierarchical composition:

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

Parallel task execution leverages the [Parallel](https://github.com/grosser/parallel) gem, which automatically detects the number of available processors to maximize concurrent task execution.

> [!IMPORTANT]
> Context cannot be modified during parallel execution. Ensure that all required data is preloaded into the context before parallelization begins.

```ruby
class SendWelcomeNotifications < CMDx::Task
  include CMDx::Workflow

  # Default options (dynamically calculated to available processors)
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel

  # Fix number of threads
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel, in_threads: 2

  # Fix number of forked processes
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel, in_processes: 2

  # NOTE: Reactors are not supported
end
```

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

> [!TIP]
> Use **present tense verbs + pluralized noun** for workflow task names, eg: `SendNotifications`, `DownloadFiles`, `ValidateDocuments`

---

- **Prev:** [Deprecation](deprecation.md)
- **Next:** [Tips and Tricks](tips_and_tricks.md)
