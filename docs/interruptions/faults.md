# Interruptions - Faults

Faults are exception mechanisms that halt task execution via `skip!` and `fail!` methods. When tasks execute with the `execute!` method, fault exceptions matching the task's interruption status are raised, enabling sophisticated exception handling and control flow patterns.

## Table of Contents

- [TLDR](#tldr)
- [Fault Types](#fault-types)
- [Exception Handling](#exception-handling)
- [Fault Context Access](#fault-context-access)
- [Advanced Matching](#advanced-matching)
- [Fault Propagation](#fault-propagation)
- [Chain Analysis](#chain-analysis)
- [Configuration](#configuration)

## TLDR

```ruby
# Basic exception handling
begin
  PaymentProcessor.execute!(amount: 100)
rescue CMDx::SkipFault => e
  handle_skipped_payment(e.result.reason)
rescue CMDx::FailFault => e
  handle_failed_payment(e.result.metadata[:error])
rescue CMDx::Fault => e
  handle_any_interruption(e)
end

# Advanced matching
rescue CMDx::FailFault.for?(PaymentProcessor, CardValidator) => e
rescue CMDx::Fault.matches? { |f| f.context.amount > 1000 } => e

# Fault propagation
throw!(validation_result) if validation_result.failed?
```

## Fault Types

| Type | Triggered By | Use Case |
|------|--------------|----------|
| `CMDx::SkipFault` | `skip!` method | Optional processing, early returns |
| `CMDx::FailFault` | `fail!` method | Validation errors, processing failures |
| `CMDx::Fault` | Base class | Catch-all for any interruption |

> [!NOTE]
> All fault exceptions inherit from `CMDx::Fault` and provide access to the complete task execution context including result, task, context, and chain information.

## Exception Handling

### Basic Rescue Patterns

```ruby
begin
  ProcessOrder.execute!(order_id: 123)
rescue CMDx::SkipFault => e
  logger.info "Order processing skipped: #{e.message}"
  schedule_retry(e.context.order_id)
rescue CMDx::FailFault => e
  logger.error "Order processing failed: #{e.message}"
  notify_customer(e.context.customer_email, e.result.metadata[:error])
rescue CMDx::Fault => e
  logger.warn "Order processing interrupted: #{e.message}"
  rollback_transaction
end
```

### Error-Specific Handling

```ruby
begin
  PaymentProcessor.execute!(card_token: token, amount: amount)
rescue CMDx::FailFault => e
  case e.result.metadata[:error_code]
  when "INSUFFICIENT_FUNDS"
    suggest_different_payment_method
  when "CARD_DECLINED"
    request_card_verification
  when "NETWORK_ERROR"
    retry_payment_later
  else
    escalate_to_support(e)
  end
end
```

## Fault Context Access

Faults provide comprehensive access to execution context:

```ruby
begin
  UserRegistration.execute!(email: email, password: password)
rescue CMDx::Fault => e
  # Result information
  e.result.status            #=> "failed" or "skipped"
  e.result.reason #=> "Email already exists"
  e.result.runtime           #=> 0.05

  # Task information
  e.task.class.name          #=> "UserRegistration"
  e.task.id                  #=> "abc123..."

  # Context data
  e.context.email            #=> "user@example.com"
  e.context.password         #=> "[FILTERED]"

  # Chain information (for workflows)
  e.chain&.id                #=> "def456..."
  e.chain&.results&.size     #=> 3
end
```

## Advanced Matching

### Task-Specific Matching

> [!TIP]
> Use `for?` to handle faults only from specific task classes, enabling targeted exception handling in complex workflows.

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

> [!IMPORTANT]
> Use `throw!` to propagate failures while preserving fault context and maintaining the error chain for debugging.

### Basic Propagation

```ruby
class OrderProcessor < CMDx::Task
  def work
    # Validate order data
    validation_result = OrderValidator.execute(context)
    throw!(validation_result) if validation_result.failed?

    # Process payment
    payment_result = PaymentProcessor.execute(context)
    throw!(payment_result) if payment_result.failed?

    # Continue processing
    complete_order
  end
end
```

### Propagation with Context

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

> [!NOTE]
> Results provide methods to analyze fault propagation and identify original failure sources in complex execution chains.

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

## Configuration

### Task Halt Settings

Control which statuses raise exceptions using `task_breakpoints`:

```ruby
class DataProcessor < CMDx::Task
  # Only failures raise exceptions
  settings(task_breakpoints: [CMDx::Result::FAILED])

  def work
    skip!(No data to process") if data.empty?
    # Skip will NOT raise exception on call!
  end
end

class CriticalValidator < CMDx::Task
  # Both failures and skips raise exceptions
  settings(task_breakpoints: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  def work
    skip!(Validation bypassed") if bypass_mode?
    # Skip WILL raise exception on call!
  end
end
```

> [!WARNING]
> Task halt configuration only affects the `execute!` method. The `execute` method always captures exceptions and converts them to result objects regardless of halt settings.

### Global Configuration

```ruby
# Configure default halt behavior
CMDx.configure do |config|
  config.task_breakpoints = [CMDx::Result::FAILED]  # Default: only failures halt
end
```

---

- **Prev:** [Interruptions - Halt](halt.md)
- **Next:** [Interruptions - Exceptions](exceptions.md)
