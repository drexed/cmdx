# Workflow

CMDx::Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business workflows from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

Workflows inherit from Task, gaining all task capabilities including callbacks, parameter validation, result tracking, and configuration. The key difference is that workflows coordinate other tasks rather than implementing business logic directly.

## Table of Contents

- [TLDR](#tldr)
- [Basic Usage](#basic-usage)
- [Task Declaration](#task-declaration)
- [Context Propagation](#context-propagation)
- [Conditional Execution](#conditional-execution)
- [Halt Behavior](#halt-behavior)
  - [Default Behavior](#default-behavior)
  - [Class-Level Configuration](#class-level-configuration)
  - [Group-Level Configuration](#group-level-configuration)
  - [Available Result Statuses](#available-result-statuses)
- [Process Method Options](#process-method-options)
- [Error Handling](#error-handling)
- [Nested Workflows](#nested-workflows)
- [Task Settings Integration](#task-settings-integration)
- [Generator](#generator)

## TLDR

```ruby
# Basic workflow - sequential task execution
class OrderWorkflow < CMDx::Workflow
  process ValidateOrderTask      # Step 1
  process CalculateTaxTask       # Step 2
  process ChargePaymentTask      # Step 3
end

# Conditional execution
process SendEmailTask, if: proc { context.notify_user? }
process SkipableTask, unless: :should_skip?

# Halt behavior control
process CriticalTask, workflow_breakpoints: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
process OptionalTask, workflow_breakpoints: []  # Never halt

# Context flows through all tasks automatically
result = OrderWorkflow.execute(order: order)
result.context.tax_amount    # Set by CalculateTaxTask
result.context.payment_id    # Set by ChargePaymentTask
```

## Basic Usage

> [!WARNING]
> Do **NOT** define a `execute` method in workflow classes. The workflow automatically provides execution logic.

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  process ValidateOrderTask
  process CalculateTaxTask
  process ChargePaymentTask
  process FulfillOrderTask
end

# Execute workflow
result = OrderProcessingWorkflow.execute(order: order, user: current_user)

if result.success?
  redirect_to order_path(result.context.order)
elsif result.failed?
  handle_error(result.metadata[:reason])
end
```

## Task Declaration

Tasks are declared using the `process` method in execution order:

```ruby
class NotificationWorkflow < CMDx::Workflow
  # Single task
  process PrepareNotificationTask

  # Multiple tasks (grouped with same options)
  process SendEmailTask, SendSmsTask, SendPushTask

  # Tasks with conditions
  process SendWebhookTask, if: proc { context.webhook_enabled? }
  process SendSlackTask, unless: :slack_disabled?

  private

  def slack_disabled?
    !context.user.slack_enabled?
  end
end
```

> [!IMPORTANT]
> Tasks execute in declaration order (FIFO). Use grouping to apply the same options to multiple tasks.

## Context Propagation

The context object flows through all tasks, creating a data pipeline:

```ruby
class PaymentWorkflow < CMDx::Workflow
  process ValidateOrderTask  # Sets context.validation_errors
  process CalculateTaxTask   # Uses context.order, sets context.tax_amount
  process ChargePaymentTask  # Uses context.tax_amount, sets context.payment_id
end

result = PaymentWorkflow.execute(order: order)
# Context contains cumulative data from all executed tasks
result.context.validation_errors  # From ValidateOrderTask
result.context.tax_amount         # From CalculateTaxTask
result.context.payment_id         # From ChargePaymentTask
```

## Conditional Execution

Tasks can execute conditionally using `:if` and `:unless` options:

```ruby
class UserWorkflow < CMDx::Workflow
  process ValidateUserTask

  # Proc condition
  process UpgradeToPremiumTask, if: proc { context.user.premium? }

  # Lambda condition
  process ProcessInternationalTask, unless: -> { context.user.domestic? }

  # Method condition
  process LogDebugInfoTask, if: :debug_enabled?

  # Complex condition
  process SendSpecialOfferTask, if: proc {
    context.user.active? &&
    context.feature_enabled?(:offers) &&
    business_hours?
  }

  private

  def debug_enabled?
    Rails.env.development?
  end

  def business_hours?
    Time.now.hour.between?(9, 17)
  end
end
```

> [!NOTE]
> Conditions are evaluated in the workflow instance context. Skipped tasks return `SKIPPED` status but don't halt execution by default.

## Halt Behavior

Workflows control execution flow by halting on specific result statuses.

### Default Behavior

By default, workflows halt on `FAILED` status but continue on `SKIPPED`:

```ruby
class DataWorkflow < CMDx::Workflow
  process LoadDataTask      # If fails → workflow stops
  process ValidateDataTask  # If skipped → workflow continues
  process SaveDataTask      # Only runs if no failures occurred
end
```

### Class-Level Configuration

Configure halt behavior for the entire workflow:

```ruby
class CriticalWorkflow < CMDx::Workflow
  # Halt on both failed and skipped results
  settings(workflow_breakpoints: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  process LoadCriticalDataTask
  process ValidateCriticalDataTask
end

class OptionalWorkflow < CMDx::Workflow
  # Never halt, always continue
  settings(workflow_breakpoints: [])

  process TryLoadDataTask
  process TryValidateDataTask
  process TrySaveDataTask
end
```

### Group-Level Configuration

Different task groups can have different halt behavior:

```ruby
class AccountWorkflow < CMDx::Workflow
  # Critical tasks - halt on any failure or skip
  process CreateUserTask, ValidateUserTask,
    workflow_breakpoints: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]

  # Optional tasks - never halt
  process SendWelcomeEmailTask, CreateProfileTask,
    workflow_breakpoints: []

  # Default behavior for remaining tasks
  process NotifyAdminTask, LogUserCreationTask
end
```

### Available Result Statuses

Use these statuses in `workflow_breakpoints` arrays:

| Status | Description |
|--------|-------------|
| `CMDx::Result::SUCCESS` | Task completed successfully |
| `CMDx::Result::SKIPPED` | Task was skipped intentionally |
| `CMDx::Result::FAILED` | Task failed due to error or validation |

## Process Method Options

The `process` method supports these options:

| Option | Description | Example |
|--------|-------------|---------|
| `:if` | Execute task if condition is true | `if: proc { context.enabled? }` |
| `:unless` | Execute task if condition is false | `unless: :should_skip?` |
| `:workflow_breakpoints` | Which statuses should halt execution | `workflow_breakpoints: [CMDx::Result::FAILED]` |

Conditions can be procs, lambdas, symbols, or strings referencing instance methods.

## Error Handling

> [!WARNING]
> Workflow failures provide detailed information about which task failed and why, enabling precise error handling and debugging.

```ruby
class OrderWorkflow < CMDx::Workflow
  process ValidateOrderTask
  process CalculateTaxTask
  process ChargePaymentTask
end

result = OrderWorkflow.execute(order: invalid_order)

if result.failed?
  result.metadata
  # {
  #   ValidateOrderTask failed: Order ID is required",
  #   failed_task: "ValidateOrderTask",
  #   task_index: 0,
  #   executed_tasks: ["ValidateOrderTask"],
  #   skipped_tasks: [],
  #   context_at_failure: { order: {...} }
  # }
end
```

### Common Error Scenarios

```ruby
# Task raises exception
class ProcessDataWorkflow < CMDx::Workflow
  process ValidateDataTask  # Raises validation error
  process TransformDataTask # Never executes
end

result = ProcessDataWorkflow.execute(data: nil)
result.failed?  #=> true
result.metadata[:reason]  #=> "ValidateDataTask failed: Data cannot be nil"

# Halt on skipped task
class StrictWorkflow < CMDx::Workflow
  process RequiredTask, workflow_breakpoints: [CMDx::Result::SKIPPED]
  process OptionalTask, if: proc { false }  # Always skipped
  process FinalTask  # Never executes
end

result = StrictWorkflow.call
result.failed?  #=> true (halted on skipped task)
```

> [!TIP]
> Use specific halt configurations to implement different failure strategies: strict validation, best-effort processing, or fault-tolerant pipelines.

## Nested Workflows

Workflows can process other workflows for hierarchical composition:

```ruby
class DataPreProcessingWorkflow < CMDx::Workflow
  process ValidateInputTask
  process SanitizeDataTask
end

class DataProcessingWorkflow < CMDx::Workflow
  process TransformDataTask
  process ApplyBusinessLogicTask
end

class CompleteDataWorkflow < CMDx::Workflow
  process DataPreProcessingWorkflow
  process DataProcessingWorkflow, if: proc { context.pre_processing_successful? }
  process GenerateReportTask
end
```

> [!NOTE]
> Nested workflows share the same context object, enabling seamless data flow across workflow boundaries.

## Task Settings Integration

Workflows support all task capabilities including parameters, callbacks, and configuration:

```ruby
class PaymentWorkflow < CMDx::Workflow
  # Parameter validation
  required :order_id, type: :integer
  optional :notify_user, type: :boolean, default: true

  # Workflow settings
  settings(
    workflow_breakpoints: [CMDx::Result::FAILED],
    log_level: :debug,
    tags: [:critical, :payment]
  )

  # Callbacks
  before_execution :setup_context
  after_execution :cleanup_resources

  process ValidateOrderTask
  process ProcessPaymentTask
  process NotifyUserTask, if: proc { context.notify_user }

  private

  def setup_context
    context.start_time = Time.now
  end

  def cleanup_resources
    context.temp_files&.each(&:delete)
  end
end
```

## Generator

Generate workflow scaffolding using the Rails generator:

```bash
rails g cmdx:workflow ProcessOrder
```

Creates `app/tasks/process_order_workflow.rb`:

```ruby
class ProcessOrderWorkflow < ApplicationWorkflow
  process # TODO: Add your tasks here
end
```

> [!NOTE]
> The generator creates workflow files in `app/tasks/`, inherits from `ApplicationWorkflow` if available (otherwise `CMDx::Workflow`), and handles proper naming conventions.

---

- **Prev:** [Middlewares](middlewares.md)
- **Next:** [Logging](logging.md)
