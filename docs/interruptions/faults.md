# Interruptions - Faults

Faults are the exception mechanisms by which CMDx halts task execution via the
`skip!` and `fail!` methods. When tasks are executed with the bang `call!` method,
fault exceptions matching the task's interruption status are raised, enabling
sophisticated exception handling and control flow patterns.

## Table of Contents

- [Fault Types](#fault-types)
- [Basic Exception Handling](#basic-exception-handling)
- [Fault Context Access](#fault-context-access)
- [Advanced Fault Matching](#advanced-fault-matching)
- [Fault Propagation (`throw!`)](#fault-propagation-throw)
- [Fault Chain Analysis](#fault-chain-analysis)
- [Task Halt Configuration](#task-halt-configuration)

## Fault Types

CMDx provides two primary fault types that inherit from the base `CMDx::Fault` class:

- **`CMDx::Skipped`** - Raised when a task is skipped via `skip!`
- **`CMDx::Failed`** - Raised when a task fails via `fail!`

Both fault types provide full access to the task execution context, including
the result object, task instance, context data, and chain information.

> [!NOTE]
> All fault exceptions (`CMDx::Skipped`, `CMDx::Failed`, and `CMDx::Fault`) inherit from the base `CMDx::Fault` class and provide access to the complete task execution context.

## Basic Exception Handling

Use standard Ruby `rescue` blocks to handle faults with custom logic:

```ruby
begin
  ProcessUserOrderTask.call!(order_id: 123)
rescue CMDx::Skipped => e
  # Handle skipped tasks
  logger.info "Task skipped: #{e.message}"
  e.result.metadata[:reason] #=> "Order already processed"
rescue CMDx::Failed => e
  # Handle failed tasks
  logger.error "Task failed: #{e.message}"
  e.result.metadata[:error_code] #=> "PAYMENT_DECLINED"
rescue CMDx::Fault => e
  # Handle any fault (skipped or failed)
  logger.warn "Task interrupted: #{e.message}"
end
```

## Fault Context Access

Faults provide comprehensive access to task execution context:

```ruby
begin
  ProcessUserOrderTask.call!(order_id: 123)
rescue CMDx::Fault => e
  # Result information
  e.result.status            #=> "failed" or "skipped"
  e.result.metadata[:reason] #=> "Insufficient inventory"
  e.result.runtime           #=> 0.05

  # Task information
  e.task.class.name          #=> "ProcessUserOrderTask"
  e.task.id                  #=> "abc123..."

  # Context data
  e.context.order_id         #=> 123
  e.context.customer_email   #=> "user@example.com"

  # Chain information
  e.chain.id                 #=> "def456..."
  e.chain.results.size       #=> 3
end
```

## Advanced Fault Matching

### Task-Specific Matching (`for?`)

Match faults only from specific task classes using the `for?` method:

```ruby
begin
  WorkflowProcessUserOrdersTask.call!(orders: orders)
rescue CMDx::Skipped.for?(ProcessUserOrderTask, ValidateUserOrderTask) => e
  # Handle skips only from specific task types
  logger.info "Order processing skipped: #{e.task.class.name}"
  reschedule_order_processing(e.context.order_id)
rescue CMDx::Failed.for?(ProcessOrderPaymentTask, ProcessCardChargeTask) => e
  # Handle failures only from payment-related tasks
  logger.error "Payment processing failed: #{e.message}"
  retry_with_backup_payment_method(e.context)
end
```

### Pattern Matching with Multiple Tasks

```ruby
# Define task groups for cleaner matching
payment_tasks = [ProcessOrderPaymentTask, ValidatePaymentCardTask, ProcessCardChargeTask]
notification_tasks = [SendOrderNotificationTask, SendOrderSMSTask, SendPushNotificationTask]

begin
  ProcessOrderWorkflowTask.call!(workflow_data: data)
rescue CMDx::Failed.for?(*payment_tasks) => e
  # Handle any payment-related failure
  escalate_payment_issue(e)
rescue CMDx::Skipped.for?(*notification_tasks) => e
  # Handle notification skips (user preferences, etc.)
  log_communication_preference_skip(e)
end
```

### Custom Matching Logic (`matches?`)

Use the `matches?` method with blocks for sophisticated fault matching:

```ruby
begin
  ProcessUserOrderTask.call!(order_id: 123)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_code] == "PAYMENT_DECLINED" } => e
  # Handle specific payment errors
  retry_with_different_payment_method(e.context)
rescue CMDx::Fault.matches? { |f| f.context.order_value > 1000 } => e
  # Handle high-value order failures differently
  escalate_to_manager(e)
rescue CMDx::Failed.matches? { |f| f.result.metadata[:reason]&.include?("timeout") } => e
  # Handle timeout-specific failures
  retry_with_longer_timeout(e)
end
```

### Complex Matching Patterns

```ruby
begin
  WorkflowProcessUserOrdersTask.call!(items: items)
rescue CMDx::Fault.matches? { |f|
  f.result.failed? &&
  f.result.metadata[:reason]&.include?("timeout") &&
  f.chain.results.count(&:failed?) < 3
} => e
  # Retry if it's a timeout with fewer than 3 failures in the chain
  retry_with_longer_timeout(e)
rescue CMDx::Fault.matches? { |f|
  f.result.skipped? &&
  f.context.priority == "low" &&
  Time.now.hour.between?(22, 6)
} => e
  # Skip low-priority tasks during off-hours
  schedule_for_business_hours(e.context)
end
```

> [!TIP]
> Use `for?` and `matches?` methods for advanced exception matching. The `for?` method is ideal for task-specific handling, while `matches?` enables custom logic-based fault filtering.

## Fault Propagation (`throw!`)

The `throw!` method enables fault propagation, allowing parent tasks to bubble up
failures from subtasks while preserving the original fault information:

### Basic Propagation

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # Execute subtask and propagate its failure
    validation_result = ValidateUserOrderTask.call(context)
    throw!(validation_result) if validation_result.failed?

    payment_result = ProcessOrderPaymentTask.call(context)
    throw!(payment_result) if payment_result.failed?

    # Continue with main logic
    finalize_order
  end

end
```

### Conditional Propagation

```ruby
class ProcessOrderFulfillmentTask < CMDx::Task

  def call
    inventory_result = ValidateOrderInventoryTask.call(context)

    # Only propagate inventory failures for high-priority orders
    if inventory_result.failed? && context.priority == "high"
      throw!(inventory_result)
    elsif inventory_result.failed?
      # Handle low-priority inventory failures differently
      schedule_backorder(context.order_id)
    end

    shipping_result = ProcessOrderShippingTask.call(context)
    throw!(shipping_result) unless shipping_result.success?
  end

end
```

### Propagation with Additional Context

```ruby
class ProcessOrderWorkflowTask < CMDx::Task

  def call
    step1_result = ValidateOrderDataTask.call(context)

    if step1_result.failed?
      # Propagate with additional context
      throw!(step1_result, {
        workflow_stage: "initial_validation",
        attempted_at: Time.now,
        can_retry: true
      })
    end

    continue_workflow
  end

end
```

> [!IMPORTANT]
> Use `throw!` to propagate failures while preserving the original fault context. This maintains the fault chain for debugging and provides better error traceability.

## Fault Chain Analysis

Results provide methods for analyzing fault propagation chains:

```ruby
result = ProcessOrderWorkflowTask.call(data: invalid_data)

if result.failed?
  # Find the original cause of failure
  original_failure = result.caused_failure
  puts "Original failure: #{original_failure.task.class.name}"
  puts "Reason: #{original_failure.metadata[:reason]}"

  # Find what threw the failure to this result
  throwing_task = result.threw_failure
  puts "Failure thrown by: #{throwing_task.task.class.name}" if throwing_task

  # Check if this result caused or threw the failure
  if result.caused_failure?
    puts "This task was the original cause"
  elsif result.threw_failure?
    puts "This task threw a failure from another task"
  elsif result.thrown_failure?
    puts "This task failed due to a thrown failure"
  end
end
```

## Task Halt Configuration

Control which statuses raise exceptions using the `task_halt` setting:

```ruby
class ProcessUserOrderTask < CMDx::Task
  # Only failed tasks raise exceptions on call!
  task_settings!(task_halt: [CMDx::Result::FAILED])

  def call
    skip!(reason: "Order already processed") if already_processed?
    # This will NOT raise an exception on call!
  end
end

class ValidateUserDataTask < CMDx::Task
  # Both failed and skipped tasks raise exceptions
  task_settings!(task_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  def call
    skip!(reason: "Validation not required") if skip_validation?
    # This WILL raise an exception on call!
  end
end
```

> [!WARNING]
> Task halt configuration only affects the `call!` method. The `call` method always captures all exceptions and converts them to result objects regardless of halt settings.

---

- **Prev:** [Interruptions - Halt](halt.md)
- **Next:** [Interruptions - Exceptions](exceptions.md)
