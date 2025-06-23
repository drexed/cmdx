# Interruptions - Faults

Faults are the exception mechanisms by which CMDx halts task execution via the
`skip!` and `fail!` methods. When tasks are executed with the bang `call!` method,
fault exceptions matching the task's interruption status are raised, enabling
sophisticated exception handling and control flow patterns.

## Fault Types

CMDx provides two primary fault types that inherit from the base `CMDx::Fault` class:

- **`CMDx::Skipped`** - Raised when a task is skipped via `skip!`
- **`CMDx::Failed`** - Raised when a task fails via `fail!`

Both fault types provide full access to the task execution context, including
the result object, task instance, context data, and run information.

## Basic Exception Handling

Use standard Ruby `rescue` blocks to handle faults with custom logic:

```ruby
begin
  ProcessOrderTask.call!(order_id: 123)
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
  ProcessOrderTask.call!(order_id: 123)
rescue CMDx::Fault => e
  # Result information
  e.result.status           #=> "failed" or "skipped"
  e.result.metadata[:reason] #=> "Insufficient inventory"
  e.result.runtime          #=> 0.05

  # Task information
  e.task.class.name         #=> "ProcessOrderTask"
  e.task.id                 #=> "abc123..."

  # Context data
  e.context.order_id        #=> 123
  e.context.customer_email  #=> "user@example.com"

  # Run information
  e.run.id                  #=> "def456..."
  e.run.results.size        #=> 3
end
```

## Advanced Fault Matching

### Task-Specific Matching (`for?`)

Match faults only from specific task classes using the `for?` method:

```ruby
begin
  BatchProcessOrdersTask.call!(orders: orders)
rescue CMDx::Skipped.for?(ProcessOrderTask, ValidateOrderTask) => e
  # Handle skips only from specific task types
  logger.info "Order processing skipped: #{e.task.class.name}"
  reschedule_order_processing(e.context.order_id)
rescue CMDx::Failed.for?(ProcessPaymentTask, ChargeCardTask) => e
  # Handle failures only from payment-related tasks
  logger.error "Payment processing failed: #{e.message}"
  retry_with_backup_payment_method(e.context)
end
```

### Pattern Matching with Multiple Tasks

```ruby
# Define task groups for cleaner matching
payment_tasks = [ProcessPaymentTask, ValidateCardTask, ChargeCardTask]
notification_tasks = [SendEmailTask, SendSMSTask, PushNotificationTask]

begin
  ProcessComplexWorkflowTask.call!(workflow_data: data)
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
  ProcessOrderTask.call!(order_id: 123)
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
  BatchProcessOrdersTask.call!(items: items)
rescue CMDx::Fault.matches? { |f|
  f.result.failed? &&
  f.result.metadata[:reason]&.include?("timeout") &&
  f.run.results.count(&:failed?) < 3
} => e
  # Retry if it's a timeout with fewer than 3 failures in the run
  retry_with_longer_timeout(e)
rescue CMDx::Fault.matches? { |f|
  f.result.skipped? &&
  f.context.priority == "low" &&
  Time.current.hour.between?(22, 6)
} => e
  # Skip low-priority tasks during off-hours
  schedule_for_business_hours(e.context)
end
```

## Fault Propagation (`throw!`)

The `throw!` method enables fault propagation, allowing parent tasks to bubble up
failures from subtasks while preserving the original fault information:

### Basic Propagation

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Execute subtask and propagate its failure
    validation_result = ValidateOrderTask.call(context)
    throw!(validation_result) if validation_result.failed?

    payment_result = ProcessPaymentTask.call(context)
    throw!(payment_result) if payment_result.failed?

    # Continue with main logic
    finalize_order
  end

end
```

### Conditional Propagation

```ruby
class FulfillOrderTask < CMDx::Task

  def call
    inventory_result = CheckInventoryTask.call(context)

    # Only propagate inventory failures for high-priority orders
    if inventory_result.failed? && context.priority == "high"
      throw!(inventory_result)
    elsif inventory_result.failed?
      # Handle low-priority inventory failures differently
      schedule_backorder(context.order_id)
    end

    shipping_result = ArrangeShippingTask.call(context)
    throw!(shipping_result) unless shipping_result.success?
  end

end
```

### Propagation with Additional Context

```ruby
class ProcessComplexWorkflowTask < CMDx::Task

  def call
    step1_result = FirstStepTask.call(context)

    if step1_result.failed?
      # Propagate with additional context
      throw!(step1_result, {
        workflow_stage: "initial_validation",
        attempted_at: Time.current,
        can_retry: true
      })
    end

    continue_workflow
  end

end
```

## Fault Chain Analysis

Results provide methods for analyzing fault propagation chains:

```ruby
result = ProcessComplexWorkflowTask.call(data: invalid_data)

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
class ProcessOrderTask < CMDx::Task
  # Only failed tasks raise exceptions on call!
  task_settings!(task_halt: [CMDx::Result::FAILED])

  def call
    skip!("Order already processed") if already_processed?
    # This will NOT raise an exception on call!
  end
end

class ValidateStrictTask < CMDx::Task
  # Both failed and skipped tasks raise exceptions
  task_settings!(task_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  def call
    skip!("Validation not required") if skip_validation?
    # This WILL raise an exception on call!
  end
end
```

## Practical Usage Patterns

### Retry Mechanisms

```ruby
def process_with_retries(order_id, max_retries: 3)
  retries = 0

  begin
    ProcessOrderTask.call!(order_id: order_id)
  rescue CMDx::Failed.matches? { |f| f.result.metadata[:error_code] == "TEMPORARY_ERROR" } => e
    retries += 1
    if retries <= max_retries
      sleep(2 ** retries) # Exponential backoff
      retry
    else
      raise e
    end
  end
end
```

### Workflow Error Handling

```ruby
class ProcessOrderWorkflowTask < CMDx::Task
  def call
    begin
      ValidateOrderTask.call!(context)
      ProcessPaymentTask.call!(context)
      ArrangeShippingTask.call!(context)
    rescue CMDx::Failed.for?(ValidateOrderTask) => e
      # Validation failures are user errors
      context.errors = e.result.metadata[:validation_errors]
      fail!("Order validation failed", user_errors: context.errors)
    rescue CMDx::Failed.for?(ProcessPaymentTask) => e
      # Payment failures might be retryable
      if e.result.metadata[:error_code] == "INSUFFICIENT_FUNDS"
        fail!("Payment declined", retryable: false)
      else
        fail!("Payment processing error", retryable: true)
      end
    rescue CMDx::Failed.for?(ArrangeShippingTask) => e
      # Shipping failures are internal errors
      logger.error "Shipping arrangement failed: #{e.message}"
      fail!("Internal shipping error", contact_support: true)
    end
  end
end
```

### Batch Processing with Fault Handling

```ruby
def process_orders_batch(order_ids)
  results = []

  order_ids.each do |order_id|
    begin
      result = ProcessOrderTask.call!(order_id: order_id)
      results << { order_id: order_id, status: "success", result: result }
    rescue CMDx::Skipped => e
      results << { order_id: order_id, status: "skipped", reason: e.message }
    rescue CMDx::Failed => e
      results << { order_id: order_id, status: "failed", error: e.message }
    end
  end

  results
end
```

## Best Practices

### Fault Matching

- **Use `for?` for task-specific handling** to isolate failures by task type
- **Use `matches?` for complex conditions** that require custom logic
- **Group related tasks** for cleaner exception handling patterns
- **Combine matching methods** for sophisticated fault routing

### Fault Propagation

- **Use `throw!` to preserve fault context** when propagating failures
- **Add contextual metadata** when propagating to enhance debugging
- **Consider conditional propagation** based on business logic
- **Maintain fault chains** for comprehensive error traceability

### Task Configuration

- **Configure `task_halt` appropriately** for your use case
- **Consider which statuses should raise exceptions** in your workflow
- **Document halt behavior** for tasks that have custom configurations
- **Test both `call` and `call!` scenarios** to ensure proper behavior

> [!IMPORTANT]
> All fault exceptions (`CMDx::Skipped`, `CMDx::Failed`, and `CMDx::Fault`)
> support the `for?` and `matches?` methods for advanced exception matching.

> [!TIP]
> Use `throw!` to propagate failures while preserving the original fault context.
> This maintains the fault chain for debugging and provides better error traceability.

---

- **Prev:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
- **Next:** [Interruptions - Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
