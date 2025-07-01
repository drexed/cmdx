# Outcomes - Statuses

Statuses represent the outcome of task execution logic, indicating how the task's business logic concluded. Statuses differ from execution states by focusing on the business outcome rather than the technical execution lifecycle. Understanding statuses is crucial for implementing proper business logic branching and error handling.

## Table of Contents

- [Status Definitions](#status-definitions)
- [Status Characteristics](#status-characteristics)
- [Status Predicates](#status-predicates)
- [Status Transitions](#status-transitions)
- [Status-Based Callbacks](#status-based-callbacks)
- [Status Metadata](#status-metadata)
- [Outcome-Based Logic](#outcome-based-logic)
- [Status Serialization and Inspection](#status-serialization-and-inspection)
- [Status vs State vs Outcome](#status-vs-state-vs-outcome)

## Status Definitions

| Status    | Description |
| --------- | ----------- |
| `success` | Task execution completed successfully with expected business outcome |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary |
| `failed`  | Task stopped execution due to business rule violations, validation errors, or exceptions |

> [!NOTE]
> Statuses focus on business outcomes, not technical execution states. A task can be technically "complete" but have a "failed" status if business logic determined the operation could not succeed.

## Status Characteristics

### Success
- **Default status** for all newly created tasks
- Indicates business logic completed as expected
- Remains even if no actual execution occurred (e.g., cached results)
- Compatible with both `complete` and `interrupted` states

### Skipped
- Indicates intentional early termination
- Business logic determined execution was unnecessary
- Often used for conditional workflows and guard clauses
- Triggered by `skip!` method with contextual metadata

### Failed
- Indicates business logic could not complete successfully
- Can result from explicit failures or caught exceptions
- Contains detailed error information in metadata
- Triggered by `fail!` method or automatic exception handling

## Status Predicates

Use status predicates to check execution outcomes:

```ruby
result = ProcessUserOrderTask.call

# Individual status checks
result.success? #=> true/false
result.skipped? #=> true/false
result.failed?  #=> true/false

# Outcome categorization
result.good?    #=> true if success OR skipped
result.bad?     #=> true if skipped OR failed (not success)
```

### Status Predicate Examples

```ruby
# Basic outcome checking
if result.success?
  process_successful_order(result.context)
  send_confirmation_email(result.context.customer)
end

# Handle different failure types
if result.failed?
  error_code = result.metadata[:error_code]
  case error_code
  when 'VALIDATION_ERROR'
    return_validation_errors(result.metadata[:errors])
  when 'PAYMENT_FAILED'
    redirect_to_payment_page(result.metadata[:payment_url])
  else
    log_generic_error(result.metadata[:reason])
  end
end

# Skip handling
if result.skipped?
  reason = result.metadata[:reason]
  logger.info "Task skipped: #{reason}"

  # Skip reasons might indicate different actions
  case reason
  when 'Already processed'
    redirect_to_status_page
  when 'Insufficient permissions'
    show_permission_error
  end
end
```

## Status Transitions

Unlike states, statuses can only transition from success to skipped/failed:

```ruby
# Valid status transitions
success -> skipped    (via skip!)
success -> failed     (via fail! or exception)

# Invalid transitions (will raise errors)
skipped -> success    # ❌ Cannot transition
skipped -> failed     # ❌ Cannot transition
failed -> success     # ❌ Cannot transition
failed -> skipped     # ❌ Cannot transition
```

> [!IMPORTANT]
> Status transitions are unidirectional and final. Once a task is marked as skipped or failed, it cannot return to success status. Design your business logic accordingly.

### Status Transition Examples

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    # Task starts with success status
    context.result.success? #=> true

    # Conditional skip
    if context.order.already_processed?
      skip!(reason: "Order already processed")
      # Status is now skipped, execution halts
    end

    # Conditional failure
    unless context.user.has_permission?
      fail!(reason: "Insufficient permissions")
      # Status is now failed, execution halts
    end

    # Continue with business logic
    process_order
    # Status remains success
  end
end
```

## Status-Based Callbacks

Results provide comprehensive callback methods for status-based logic:

```ruby
result = ProcessUserOrderTask.call

# Individual status callbacks
result
  .on_success { |r| handle_success(r) }
  .on_skipped { |r| handle_skip(r) }
  .on_failed { |r| handle_failure(r) }

# Outcome-based callbacks
result
  .on_good { |r| log_positive_outcome(r) }
  .on_bad { |r| log_negative_outcome(r) }
```

### Advanced Callback Patterns

```ruby
ProcessUserOrderTask
  .call(order_id: 123)
  .on_success { |result|
    # Business success logic
    OrderMailer.confirmation_email(result.context.order).deliver
    AnalyticsService.track_order_completed(result.context.order)
    InventoryService.update_stock(result.context.order)
  }
  .on_skipped { |result|
    # Skip handling logic
    case result.metadata[:reason]
    when 'duplicate_order'
      redirect_to_existing_order(result.metadata[:existing_order_id])
    when 'out_of_stock'
      NotificationService.stock_alert(result.metadata[:product_id])
    end
  }
  .on_failed { |result|
    # Failure handling logic
    ErrorReporter.notify(result.metadata[:exception])

    if result.metadata[:retryable]
      RetryService.schedule(result.task.class, result.context.to_h)
    else
      FailureNotificationService.alert_support_team(result)
    end
  }
  .on_bad { |result|
    # Common logic for any non-success outcome
    MetricsService.increment_counter('order_processing_issues')
    AuditService.log_outcome(result)
  }
```

> [!TIP]
> Use status-based callbacks for business logic branching. The `on_good` and `on_bad` callbacks are particularly useful for handling success/skip vs failed outcomes respectively.

## Status Metadata

Statuses carry rich metadata providing context about execution outcomes:

### Success Metadata

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    # Success metadata can include business context
    context.order = Order.find(context.order_id)
    context.order.process!

    # Success status typically has empty metadata
    # but can include business-relevant information
    context.processing_time = Time.now - context.start_time
    context.confirmation_number = generate_confirmation
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
result.success?  #=> true
result.metadata  #=> {} (usually empty for success)
```

### Skip Metadata

```ruby
class ProcessUserOrderTask < CMDx::Task
  def call
    order = Order.find(context.order_id)

    if order.already_processed?
      skip!(
        reason: "Order already processed",
        processed_at: order.processed_at,
        original_processor: order.processor_id,
        skip_code: "DUPLICATE_PROCESSING"
      )
    end

    # Continue processing...
  end
end

result = ProcessUserOrderTask.call(order_id: 123)
if result.skipped?
  result.metadata[:reason]              #=> "Order already processed"
  result.metadata[:processed_at]        #=> 2023-10-01 10:30:00 UTC
  result.metadata[:original_processor]  #=> "user-456"
  result.metadata[:skip_code]           #=> "DUPLICATE_PROCESSING"
end
```

### Failure Metadata

```ruby
class ValidateOrderDataTask < CMDx::Task
  def call
    unless context.order.valid?
      fail!(
        reason: "Order validation failed",
        errors: context.order.errors.full_messages,
        error_code: "VALIDATION_FAILED",
        retryable: false,
        failed_at: Time.now
      )
    end
  end
end

result = ValidateOrderDataTask.call(order_id: 123)
if result.failed?
  result.metadata[:reason]      #=> "Order validation failed"
  result.metadata[:errors]      #=> ["Name can't be blank", "Email is invalid"]
  result.metadata[:error_code]  #=> "VALIDATION_FAILED"
  result.metadata[:retryable]   #=> false
  result.metadata[:failed_at]   #=> 2023-10-01 10:30:00 UTC
end
```

> [!TIP]
> Always try to include rich metadata with skip and fail operations. This information is invaluable for debugging, user feedback, and automated error handling.

## Outcome-Based Logic

Statuses enable sophisticated outcome-based decision making:

### Good vs Bad Outcomes

```ruby
# Good outcomes (success OR skipped)
result.good? #=> true if success? || skipped?
result.bad?  #=> true if !success? (skipped OR failed)

# Usage patterns
if result.good?
  # Both success and skipped are "good" outcomes
  update_user_interface(result)
  log_completed_action(result)
end

if result.bad?
  # Handle any non-success outcome (skipped or failed)
  show_error_message(result.metadata[:reason])
  track_negative_outcome(result)
end
```

### Status-Based Branching

```ruby
def handle_order_processing(result)
  case result.status
  when 'success'
    # Happy path
    redirect_to_confirmation_page(result.context.order)

  when 'skipped'
    # Conditional logic determined skip was appropriate
    reason = result.metadata[:reason]
    case reason
    when 'duplicate_order'
      redirect_to_existing_order_page
    when 'inventory_unavailable'
      redirect_to_back_order_page
    else
      redirect_to_status_page(reason)
    end

  when 'failed'
    # Something went wrong
    error_code = result.metadata[:error_code]
    if result.metadata[:retryable]
      show_retry_option(error_code)
    else
      show_permanent_error(error_code)
    end
  end
end
```

## Status Serialization and Inspection

Statuses are fully captured in result serialization:

```ruby
result = ProcessUserOrderTask.call

# Hash representation
result.to_h[:status]  #=> "success"

# Full serialization includes status
result.to_h
#=> {
#     class: "ProcessUserOrderTask",
#     index: 0,
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     metadata: {},
#     # ... other attributes
#   }

# Human-readable inspection
result.to_s
#=> "ProcessUserOrderTask: type=Task index=0 state=complete status=success outcome=success..."
```

## Status vs State vs Outcome

Understanding the relationship between these concepts:

- **Status**: Business execution outcome (`success`, `skipped`, `failed`)
- **State**: Technical execution lifecycle (`initialized`, `executing`, `complete`, `interrupted`)
- **Outcome**: Combined representation for unified logic

```ruby
result = ProcessUserOrderTask.call

# Different scenarios
result.state    #=> "complete"
result.status   #=> "success"
result.outcome  #=> "success" (same as status when complete)

# Skipped task
skipped_result.state    #=> "complete" (execution finished)
skipped_result.status   #=> "skipped" (business outcome)
skipped_result.outcome  #=> "skipped" (same as status)

# Failed task
failed_result.state     #=> "interrupted" (execution stopped)
failed_result.status    #=> "failed" (business outcome)
failed_result.outcome   #=> "interrupted" (reflects state for interrupted tasks)
```

---

- **Prev:** [Outcomes - Result](https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md)
- **Next:** [Outcomes - States](https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md)
