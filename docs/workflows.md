# Workflows

CMDx::Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business logic from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

## Table of Contents

- [Declarations](#declarations)
  - [Task](#task)
  - [Group](#group)
  - [Conditionals](#conditionals)
- [Halt Behavior](#halt-behavior)
  - [Task Configuration](#task-configuration)
  - [Group Configuration](#group-configuration)
- [Nested Workflows](#nested-workflows)

## Declarations

Tasks execute in declaration order (FIFO). The workflow context propagates to each task, allowing access to data from previous executions.

> [!WARNING]
> Do **NOT** define a `work` method in workflow tasks.
> The included module automatically provides the execution logic.

### Task

```ruby
class NotificationWorkflow < CMDx::Task
  include CMDx::Workflow

  task SendNotificationCheck
  task PrepNotificationTemplate

  tasks SendEmail, SendSms, SendPush
end
```

### Group

Group related tasks for better organization and shared configuration:

```ruby
class DataProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  # Validation phase
  tasks ValidateInput, ValidateSchema, ValidateBusinessRules, breakpoints: ["skipped"]

  # Processing phase
  tasks TransformData, ApplyRules, CalculateMetrics

  # Output phase
  tasks GenerateReport, SaveResults, NotifyStakeholders
end
```

> [!IMPORTANT]
> Settings and conditionals for a group apply to all tasks within that group.

### Conditionals

Conditionals support multiple syntaxes for flexible execution control:

```ruby
class DeliveryCheck
  def call(task)
    task.context.user.can?(:send_email)
  end
end

class NotificationWorkflow < CMDx::Task
  include CMDx::Workflow

  # If and/or Unless
  task SendEmail, if: :email_available?, unless: :email_temporary?

  # Proc
  task SendEmail, if: ->(workflow) { Rails.env.production? && workflow.class.name.include?("Zip") }

  # Lambda
  task SendEmail, if: proc { |workflow| workflow.context.products_on_backorder? }

  # Class or Module
  task SendEmail, unless: AbilityCheck

  # Instance
  task SendEmail, if: AbilityCheck.new

  # Conditional applies to all tasks of this declaration group
  tasks SendEmail, SendSms, SendPush, if: :email_available?

  private

  def email_available?
    context.user.email.present?
  end

  def email_temporary?
    context.user.email_service == :temporary
  end
end
```

## Halt Behavior

By default skipped tasks are considered no-op executions and does not stop workflow execution.
This is configurable via global and task level breakpoint settings. Task and group configurations
can be used together within a workflow.

```ruby
class DataWorkflow < CMDx::Task
  include CMDx::Workflow

  task LoadDataTask      # If fails → workflow stops
  task ValidateDataTask  # If skipped → workflow continues
  task SaveDataTask      # Only runs if no failures occurred
end
```

### Task Configuration

Configure halt behavior for the entire workflow:

```ruby
class CriticalWorkflow < CMDx::Task
  include CMDx::Workflow

  # Halt on both failed and skipped results
  settings(workflow_breakpoints: ["skipped", "failed"])

  task LoadCriticalDataTask
  task ValidateCriticalDataTask
end

class OptionalWorkflow < CMDx::Task
  include CMDx::Workflow

  # Never halt, always continue
  settings(breakpoints: [])

  task TryLoadDataTask
  task TryValidateDataTask
  task TrySaveDataTask
end
```

### Group Configuration

Different task groups can have different halt behavior:

```ruby
class AccountWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUser, ValidateUser, workflow_breakpoints: ["skipped", "failed"]

  # Never halt, always continue
  task SendWelcomeEmail, CreateProfile, breakpoints: []
end
```

## Nested Workflows

Workflows can task other workflows for hierarchical composition:

```ruby
class DataPreProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateInputTask
  task SanitizeDataTask
end

class DataProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  tasks TransformDataTask, ApplyBusinessLogicTask
end

class CompleteDataWorkflow < CMDx::Task
  include CMDx::Workflow

  task DataPreProcessingWorkflow
  task DataProcessingWorkflow, if: proc { context.pre_processing_successful? }
  task GenerateReportTask
end
```

---

- **Prev:** [Middlewares](middlewares.md)
- **Next:** [Logging](logging.md)
