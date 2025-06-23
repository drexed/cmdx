# Batch

A CMDx::Batch orchestrates sequential execution of multiple tasks in a linear pipeline. Batches provide a declarative DSL for composing complex business workflows from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

Batches inherit from Task, gaining all task capabilities including hooks, parameter validation, result tracking, and configuration. The key difference is that batches coordinate other tasks rather than implementing business logic directly.

> [!WARNING]
> Do **NOT** define a `call` method in batch classes. The batch class automatically provides the call logic.

## Basic Usage

```ruby
class BatchProcessOrders < CMDx::Batch
  # Sequential task execution
  process ValidateOrderTask
  process CalculateTaxTask
  process ChargePaymentTask
  process FulfillOrderTask
end

# Execute the batch
result = BatchProcessOrders.call(order: order, user: current_user)

if result.success?
  redirect_to success_path
elsif result.failed?
  flash[:error] = "Order processing failed: #{result.metadata[:reason]}"
  redirect_to cart_path
end
```

## Task Declaration

Tasks are declared using the `process` method and organized into groups with shared execution options. Multiple calls to `process` create separate groups that can have different conditional logic and halt behavior.

```ruby
class BatchSendNotifications < CMDx::Batch
  # Single task declaration
  process PrepareNotificationTask

  # Multiple tasks in one declaration (grouped)
  process SendEmailTask, SendSmsTask, SendPushTask

  # Tasks with specific options
  process SendWebhookTask, if: proc { context.webhook_enabled? }
  process SendSmsTask, unless: :sms_disabled?

  # Critical tasks with custom halt behavior
  process CoreTask1, CoreTask2, batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]

  # Optional tasks that never halt execution
  process OptionalTask1, OptionalTask2, batch_halt: []

  private

  def sms_disabled?
    !context.user.sms_enabled?
  end
end
```

> [!IMPORTANT]
> Process steps are executed in the order they are declared (FIFO: first in, first out).

## Execution Flow

Batch execution follows a structured algorithm:

1. **Group Iteration**: Process each group in declaration order
2. **Condition Evaluation**: Check `:if`/`:unless` conditions for the group
3. **Task Execution**: Run each task in the group sequentially
4. **Result Evaluation**: Check task result against halt conditions
5. **Halt Decision**: Stop execution if halt conditions are met, otherwise continue
6. **Context Propagation**: Pass updated context to next task/group

## Context Propagation

The context object is shared across all tasks in the batch, creating a data pipeline:

```ruby
class BatchProcessEcommerce < CMDx::Batch
  process ValidateOrderTask      # Sets context.validation_result
  process CalculateTaxTask       # Uses context.order, sets context.tax_amount
  process ChargePaymentTask      # Uses context.tax_amount, sets context.payment_id
  process FulfillOrderTask       # Uses context.payment_id, sets context.tracking_number
end

result = BatchProcessEcommerce.call(order: order)
# Final context contains data from all executed tasks
result.context.validation_result  # From ValidateOrderTask
result.context.tax_amount        # From CalculateTaxTask
result.context.payment_id        # From ChargePaymentTask
result.context.tracking_number   # From FulfillOrderTask
```

## Conditional Execution

Tasks can be executed conditionally using `:if` and `:unless` options. Conditions can be procs, lambdas, or method names:

```ruby
class BatchProcessConditional < CMDx::Batch
  # Always execute
  process BaseTask

  # Proc condition
  process PremiumTask, if: proc { context.user.premium? }

  # Lambda condition
  process InternationalTask, unless: -> { context.order.domestic? }

  # Method condition
  process DebugTask, if: :debug_enabled?

  # Complex condition
  process AdvancedTask, if: proc {
    context.user.active? &&
    context.feature_enabled?(:advanced_features) &&
    Time.current.hour.between?(9, 17)
  }

  private

  def debug_enabled?
    Rails.env.development?
  end
end
```

## Halt Behavior

Batches control execution flow through halt behavior, which determines when to stop processing based on task results.

### Default Behavior

By default, batches halt on `FAILED` status but continue on `SKIPPED`. This reflects the philosophy that skipped tasks are bypass mechanisms, not execution blockers.

```ruby
class BatchProcessWithDefaultHalt < CMDx::Batch
  process TaskA    # If this fails, batch stops
  process TaskB    # If this is skipped, batch continues
  process TaskC    # This only runs if TaskA succeeds
end
```

### Class-Level Configuration

Configure halt behavior for the entire batch using `task_settings!`:

```ruby
class BatchProcessStrict < CMDx::Batch
  # Halt on both failed and skipped results
  task_settings!(batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  process CriticalTask
  process AnotherCriticalTask
end

class BatchProcessPermissive < CMDx::Batch
  # Never halt, always continue
  task_settings!(batch_halt: [])

  process OptionalTask1
  process OptionalTask2
  process OptionalTask3
end
```

### Group-Level Configuration

Different groups can have different halt behavior:

```ruby
class BatchProcessFlexible < CMDx::Batch
  # Critical tasks - halt on any failure or skip
  process CoreTask1, CoreTask2,
    batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]

  # Optional tasks - never halt execution
  process OptionalTask1, OptionalTask2, batch_halt: []

  # Notification tasks - use default behavior (halt on failed only)
  process NotifyTask1, NotifyTask2
end
```

### Available Result Statuses

The following result statuses can be used in `batch_halt` arrays:

- `CMDx::Result::SUCCESS` - Task completed successfully
- `CMDx::Result::SKIPPED` - Task was skipped intentionally
- `CMDx::Result::FAILED` - Task failed due to error or validation

## Process Method Options

The `process` method supports the following options:

| Option        | Description |
| ------------- | ----------- |
| `:if`         | Specifies a callable method, proc or string to determine if processing steps should occur. |
| `:unless`     | Specifies a callable method, proc, or string to determine if processing steps should not occur. |
| `:batch_halt` | Sets which result statuses processing of further steps should be prevented. (default: `CMDx::Result::FAILED`) |

### Condition Callables

Conditions can be provided in several formats:

```ruby
class BatchProcessWithConditions < CMDx::Batch
  # Proc - executed in batch instance context
  process TaskA, if: proc { context.user.admin? }

  # Lambda - executed in batch instance context
  process TaskB, unless: -> { context.maintenance_mode? }

  # Symbol - method name called on batch instance
  process TaskC, if: :feature_enabled?

  # String - method name called on batch instance
  process TaskD, unless: "skip_task?"

  private

  def feature_enabled?
    context.features.include?(:advanced)
  end

  def skip_task?
    context.skip_optional_tasks?
  end
end
```

## Nested Batches

Batches can process other batches, creating hierarchical workflows:

```ruby
class BatchPreProcess < CMDx::Batch
  process ValidateInputTask
  process SanitizeDataTask
end

class BatchProcessCore < CMDx::Batch
  process TransformDataTask
  process ProcessBusinessLogicTask
end

class BatchPostProcess < CMDx::Batch
  process GenerateReportTask
  process SendNotificationTask
end

class BatchProcessMaster < CMDx::Batch
  process BatchPreProcess
  process BatchProcessCore, if: proc { context.pre_processing_successful? }
  process BatchPostProcess, unless: proc { context.skip_post_processing? }
end
```

## Error Handling

Batch execution follows the same error handling patterns as individual tasks:

```ruby
class BatchHandleErrors < CMDx::Batch
  process TaskA  # May raise exceptions
  process TaskB  # May fail validation
  process TaskC  # May return fault results
end

result = BatchHandleErrors.call(data: invalid_data)

case result.status
when "success"
  # All tasks completed successfully
  handle_success(result)
when "failed"
  # At least one task failed
  handle_failure(result)  # result.metadata contains error details
when "skipped"
  # Batch was skipped entirely
  handle_skip(result)
end
```

## Task Settings Integration

Batches support all task settings and can be configured like regular tasks:

```ruby
class BatchProcessConfigured < CMDx::Batch
  # Configure batch-specific settings
  task_settings!(
    batch_halt: [CMDx::Result::FAILED],
    log_level: :debug,
    tags: [:critical, :payment]
  )

  # Parameter validation
  required :order_id, type: :integer
  optional :notify_user, type: :boolean, default: true

  # Hooks
  before_execution :setup_context
  after_execution :cleanup_resources

  process ValidateOrderTask
  process ProcessOrderTask
  process NotifyUserTask, if: proc { context.notify_user }

  private

  def setup_context
    context.start_time = Time.current
  end

  def cleanup_resources
    context.temp_files&.each(&:delete)
  end
end
```

## Generator

Generate a new batch using the Rails generator:

```bash
rails g cmdx:batch ProcessOrder
```

This creates a batch template file under `app/cmds`:

```ruby
class BatchProcessOrder < ApplicationBatch
  process # TODO
end
```

The generator:
- Creates batch files in `app/commands/batch_[name].rb`
- Inherits from `ApplicationBatch` if available, otherwise `CMDx::Batch`
- Handles proper naming conventions (removes "Batch" prefix if provided)
- Follows Rails generator conventions for class names and file paths

---

- **Prev:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
- **Next:** [Logging](https://github.com/drexed/cmdx/blob/main/docs/logging.md)
