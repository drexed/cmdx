# Workflow

A CMDx::Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business workflows from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

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
  - [Condition Callables](#condition-callables)
- [Nested Workflows](#nested-workflows)
- [Task Settings Integration](#task-settings-integration)
- [Generator](#generator)

## TLDR

- **Purpose** - Orchestrate sequential execution of multiple tasks in linear pipeline
- **Declaration** - Use `process` method to declare tasks in execution order
- **Context sharing** - Context object shared across all tasks for data pipeline
- **Conditional execution** - Support `:if` and `:unless` options for conditional tasks
- **Halt behavior** - Configurable stopping on failed/skipped results (default: halt on failed only)
- **No call method** - Workflows automatically provide execution logic, don't define `call`

## Basic Usage

> [!WARNING]
> Do **NOT** define a `call` method in workflow classes. The workflow class automatically provides the call logic.

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  # Sequential task execution
  process ValidateOrderTask
  process CalculateTaxTask
  process ChargePaymentTask
  process FulfillOrderTask
end

# Execute the workflow
result = WorkflowProcessOrders.call(order: order, user: current_user)

if result.success?
  redirect_to success_path
elsif result.failed?
  flash[:error] = "Order processing failed: #{result.metadata[:reason]}"
  redirect_to cart_path
end
```

## Task Declaration

Tasks are declared using the `process` method and organized into groups with shared execution options:

```ruby
class NotificationDeliveryWorkflow < CMDx::Workflow
  # Single task declaration
  process PrepareNotificationTask

  # Multiple tasks in one declaration (grouped)
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
> Process steps are executed in the order they are declared (FIFO: first in, first out).

## Context Propagation

The context object is shared across all tasks in the workflow, creating a data pipeline:

```ruby
class EcommerceProcessingWorkflow < CMDx::Workflow
  process ValidateOrderTask # Sets context.validation_result
  process CalculateTaxTask  # Uses context.order, sets context.tax_amount
  process ChargePaymentTask # Uses context.tax_amount, sets context.payment_id
  process FulfillOrderTask  # Uses context.payment_id, sets context.tracking_number
end

result = WorkflowProcessEcommerce.call(order: order)
# Final context contains data from all executed tasks
result.context.validation_result # From ValidateOrderTask
result.context.tax_amount        # From CalculateTaxTask
result.context.payment_id        # From ChargePaymentTask
result.context.tracking_number   # From FulfillOrderTask
```

## Conditional Execution

Tasks can be executed conditionally using `:if` and `:unless` options. Conditions can be procs, lambdas, or method names:

```ruby
class UserProcessingWorkflow < CMDx::Workflow
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
    Time.now.hour.between?(9, 17)
  }

  private

  def debug_enabled?
    Rails.env.development?
  end
end
```

## Halt Behavior

Workflows control execution flow through halt behavior, which determines when to stop processing based on task results.

### Default Behavior

By default, workflows halt on `FAILED` status but continue on `SKIPPED`. This reflects the philosophy that skipped tasks are bypass mechanisms, not execution blockers.

```ruby
class DataProcessingWorkflow < CMDx::Workflow
  process LoadDataTask     # If this fails, workflow stops
  process ValidateDataTask # If this is skipped, workflow continues
  process SaveDataTask     # This only runs if LoadDataTask and ValidateDataTask don't fail
end
```

### Class-Level Configuration

Configure halt behavior for the entire workflow using `cmd_settings!`:

```ruby
class CriticalDataProcessingWorkflow < CMDx::Workflow
  # Halt on both failed and skipped results
  cmd_settings!(workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  process LoadCriticalDataTask
  process ValidateCriticalDataTask
end

class OptionalDataProcessingWorkflow < CMDx::Workflow
  # Never halt, always continue
  cmd_settings!(workflow_halt: [])

  process TryLoadDataTask
  process TryValidateDataTask
  process TrySaveDataTask
end
```

### Group-Level Configuration

Different groups can have different halt behavior:

```ruby
class UserAccountProcessingWorkflow < CMDx::Workflow
  # Critical tasks - halt on any failure or skip
  process CreateUserTask, ValidateUserTask,
    workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]

  # Optional tasks - never halt execution
  process SendWelcomeEmailTask, CreateProfileTask, workflow_halt: []

  # Notification tasks - use default behavior (halt on failed only)
  process NotifyAdminTask, LogUserCreationTask
end
```

### Available Result Statuses

The following result statuses can be used in `workflow_halt` arrays:

- `CMDx::Result::SUCCESS` - Task completed successfully
- `CMDx::Result::SKIPPED` - Task was skipped intentionally
- `CMDx::Result::FAILED` - Task failed due to error or validation

## Process Method Options

The `process` method supports the following options:

| Option        | Description |
| ------------- | ----------- |
| `:if`         | Specifies a callable method, proc or string to determine if processing steps should occur. |
| `:unless`     | Specifies a callable method, proc, or string to determine if processing steps should not occur. |
| `:workflow_halt` | Sets which result statuses processing of further steps should be prevented. (default: `CMDx::Result::FAILED`) |

### Condition Callables

Conditions can be provided in several formats:

```ruby
class AccountProcessingWorkflow < CMDx::Workflow
  # Proc - executed in workflow instance context
  process UpgradeAccountTask, if: proc { context.user.admin? }

  # Lambda - executed in workflow instance context
  process MaintenanceModeTask, unless: -> { context.maintenance_mode? }

  # Symbol - method name called on workflow instance
  process AdvancedFeatureTask, if: :feature_enabled?

  # String - method name called on workflow instance
  process OptionalTask, unless: "skip_task?"

  private

  def feature_enabled?
    context.features.include?(:advanced)
  end

  def skip_task?
    context.skip_optional_tasks?
  end
end
```

## Nested Workflows

Workflows can process other workflows, creating hierarchical workflows:

```ruby
class DataPreProcessingWorkflow < CMDx::Workflow
  process ValidateInputTask
  process SanitizeDataTask
end

class DataProcessingWorkflow < CMDx::Workflow
  process TransformDataTask
  process ApplyBusinessLogicTask
end

class DataPostProcessingWorkflow < CMDx::Workflow
  process GenerateReportTask
  process SendNotificationTask
end

class CompleteDataProcessingWorkflow < CMDx::Workflow
  process DataPreProcessingWorkflow
  process DataProcessingWorkflow, if: proc { context.pre_processing_successful? }
  process DataPostProcessingWorkflow, unless: proc { context.skip_post_processing? }
end
```

## Task Settings Integration

Workflows support all task settings and can be configured like regular tasks:

```ruby
class PaymentProcessingWorkflow < CMDx::Workflow
  # Configure workflow-specific settings
  cmd_settings!(
    workflow_halt: [CMDx::Result::FAILED],
    log_level: :debug,
    tags: [:critical, :payment]
  )

  # Parameter validation
  required :order_id, type: :integer
  optional :notify_user, type: :boolean, default: true

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

Generate a new workflow using the Rails generator:

```bash
rails g cmdx:workflow ProcessOrder
```

This creates a workflow template file under `app/cmds`:

```ruby
class OrderProcessingWorkflow < ApplicationWorkflow
  process # TODO
end
```

> [!NOTE]
> The generator creates workflow files in `app/commands/workflow_[name].rb`, inherits from `ApplicationWorkflow` if available (otherwise `CMDx::Workflow`) and handles proper naming conventions.

---

- **Prev:** [Middlewares](middlewares.md)
- **Next:** [Logging](logging.md)
