# Interruptions - Faults

Faults are exception mechanisms that halt task execution via `skip!` and `fail!` methods. When tasks execute with the `execute!` method, fault exceptions matching the task's interruption status are raised, enabling sophisticated exception handling and control flow patterns.

## Table of Contents

- [Fault Types](#fault-types)
- [Fault Handling](#fault-handling)
- [Data Access](#data-access)
- [Advanced Matching](#advanced-matching)
  - [Task-Specific Matching](#task-specific-matching)
  - [Custom Logic Matching](#custom-logic-matching)
- [Fault Propagation](#fault-propagation)
  - [Basic Propagation](#basic-propagation)
  - [Additional Metadata](#additional-metadata)
- [Chain Analysis](#chain-analysis)

## Fault Types

| Type | Triggered By | Use Case |
|------|--------------|----------|
| `CMDx::SkipFault` | `skip!` method | Optional processing, early returns |
| `CMDx::FailFault` | `fail!` method | Validation errors, processing failures |
| `CMDx::Fault` | Base class | Catch-all for any interruption |

> [!NOTE]
> All fault exceptions inherit from `CMDx::Fault` and provide access to the complete task execution context including result, task, context, and chain information.

## Fault Handling

```ruby
begin
  ProcessOrder.execute!(order_id: 123)
rescue CMDx::SkipFault => e
  logger.info "Order processing skipped: #{e.message}"
  schedule_retry(e.context.order_id)
rescue CMDx::FailFault => e
  logger.error "Order processing failed: #{e.message}"
  notify_customer(e.context.customer_email, e.result.metadata[:code])
rescue CMDx::Fault => e
  logger.warn "Order processing interrupted: #{e.message}"
  rollback_transaction
end
```

## Data Access

Faults provide comprehensive access to execution context:

```ruby
begin
  UserRegistration.execute!(email: email, password: password)
rescue CMDx::Fault => e
  # Result information
  e.result.state     #=> "interrupted"
  e.result.status    #=> "failed" or "skipped"
  e.result.reason    #=> "Email already exists"

  # Task information
  e.task.class       #=> #<UserRegistration ...>
  e.task.id          #=> "abc123..."

  # Context data
  e.context.email    #=> "user@example.com"
  e.context.password #=> "[FILTERED]"

  # Chain information
  e.chain.id         #=> "def456..."
  e.chain.size       #=> 3
end
```

## Advanced Matching

### Task-Specific Matching

Use `for?` to handle faults only from specific task classes, enabling targeted exception handling in complex workflows.

```ruby
begin
  PaymentWorkflow.execute!(payment_data: data)
rescue CMDx::FailFault.for?(CardValidator, PaymentProcessor) => e
  # Handle only payment-related failures
  retry_with_backup_method(e.context)
rescue CMDx::SkipFault.for?(FraudCheck, RiskAssessment) => e
  # Handle security-related skips
  flag_for_manual_review(e.context.transaction_id)
end
```

### Custom Logic Matching

```ruby
begin
  OrderProcessor.execute!(order: order_data)
rescue CMDx::Fault.matches? { |f| f.context.order_value > 1000 } => e
  escalate_high_value_failure(e)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:retry_count] > 3 } => e
  abandon_processing(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "timeout" } => e
  increase_timeout_and_retry(e)
end
```

## Fault Propagation

Use `throw!` to propagate failures while preserving fault context and maintaining the error chain for debugging.

### Basic Propagation

```ruby
class OrderProcessor < CMDx::Task
  def work
    # Validate order
    validation_result = OrderValidator.execute(context)
    throw!(validation_result) # Skipped or Failed

    # Check inventory
    check_inventory = CheckInventory.execute(context)
    throw!(check_inventory) if check_inventory.skipped?

    # Process payment
    payment_result = PaymentProcessor.execute(context)
    throw!(payment_result) if payment_result.failed?

    # Continue processing
    complete_order
  end
end
```

### Additional Metadata

```ruby
class WorkflowProcessor < CMDx::Task
  def work
    step_result = DataValidation.execute(context)

    if step_result.failed?
      throw!(step_result, {
        workflow_stage: "validation",
        can_retry: true,
        next_step: "data_cleanup"
      })
    end

    continue_workflow
  end
end
```

## Chain Analysis

Results provide methods to analyze fault propagation and identify original failure sources in complex execution chains.

```ruby
result = PaymentWorkflow.execute(invalid_data)

if result.failed?
  # Trace the original failure
  original = result.caused_failure
  if original
    puts "Original failure: #{original.task.class.name}"
    puts "Reason: #{original.reason}"
  end

  # Find what propagated the failure
  thrower = result.threw_failure
  puts "Propagated by: #{thrower.task.class.name}" if thrower

  # Analyze failure type
  case
  when result.caused_failure?
    puts "This task was the original source"
  when result.threw_failure?
    puts "This task propagated a failure"
  when result.thrown_failure?
    puts "This task failed due to propagation"
  end
end
```

---

- **Prev:** [Interruptions - Halt](halt.md)
- **Next:** [Interruptions - Exceptions](exceptions.md)
