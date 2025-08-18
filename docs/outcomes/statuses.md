# Outcomes - Statuses

Statuses represent the business outcome of task execution logic, indicating how the task's business logic concluded. Statuses differ from execution states by focusing on the business outcome rather than the technical execution lifecycle. Understanding statuses is crucial for implementing proper business logic branching and error handling.

## Table of Contents

- [TLDR](#tldr)
- [Status Definitions](#status-definitions)
- [Status Transitions](#status-transitions)
- [Status Predicates](#status-predicates)
- [Status-Based Callbacks](#status-based-callbacks)
- [Status Metadata](#status-metadata)
- [Outcome-Based Logic](#outcome-based-logic)
- [Status vs State vs Outcome](#status-vs-state-vs-outcome)
- [Status Serialization and Inspection](#status-serialization-and-inspection)

## TLDR

```ruby
# Check business outcomes
result.success?  #=> true (default outcome)
result.skipped?  #=> false (via skip!)
result.failed?   #=> false (via fail!)

# Outcome-based logic
result.good?     #=> true (success OR skipped)
result.bad?      #=> false (skipped OR failed)

# Status-based callbacks
result
  .on_success { |r| process_success(r) }
  .on_skipped { |r| handle_skip_condition(r) }
  .on_failed { |r| handle_business_failure(r) }

# Statuses: HOW it ended, States: WHERE in lifecycle
result.status  #=> "success" (business outcome)
result.state   #=> "complete" (execution lifecycle)
```

## Status Definitions

> [!IMPORTANT]
> Statuses represent business outcomes, not technical execution states. A task can be technically "complete" but have a "failed" status if business logic determined the operation could not succeed.

| Status | Description |
| ------ | ----------- |
| `success` | Task execution completed successfully with expected business outcome. Default status for all tasks. |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary. |
| `failed` | Task stopped execution due to business rule violations, validation errors, or exceptions. |

## Status Transitions

> [!WARNING]
> Status transitions are unidirectional and final. Once a task is marked as skipped or failed, it cannot return to success status. Design your business logic accordingly.

Unlike states, statuses can only transition from success to skipped/failed:

```ruby
# Valid status transitions
success → skipped    # via skip!
success → failed     # via fail! or exception

# Invalid transitions (will raise errors)
skipped → success    # ❌ Cannot transition
skipped → failed     # ❌ Cannot transition
failed → success     # ❌ Cannot transition
failed → skipped     # ❌ Cannot transition
```

### Status Transition Examples

```ruby
class ProcessOrder < CMDx::Task
  def call
    # Task starts with success status
    context.result.success? #=> true

    # Conditional skip
    if context.order.already_processed?
      skip!(Order already processed")
      # Status is now skipped, execution halts
    end

    # Conditional failure
    unless context.user.authorized?
      fail!(Insufficient permissions")
      # Status is now failed, execution halts
    end

    # Continue with business logic
    process_order
    # Status remains success
  end
end
```

## Status Predicates

Use status predicates to check execution outcomes:

```ruby
class PaymentProcessing < CMDx::Task
  def call
    charge_customer
    send_receipt
  end
end

result = PaymentProcessingTask.call

# Individual status checks
result.success? #=> true/false
result.skipped? #=> true/false
result.failed?  #=> true/false

# Outcome categorization
result.good?    #=> true if success OR skipped
result.bad?     #=> true if skipped OR failed (not success)
```

### Status Checking in Business Logic

```ruby
def handle_payment_result(result)
  if result.success?
    send_confirmation_email(result.context.customer)
  elsif result.skipped?
    log_skip_reason(result.metadata[:reason])
  elsif result.failed?
    handle_payment_failure(result.metadata)
  end
end
```

## Status-Based Callbacks

> [!TIP]
> Use status-based callbacks for business logic branching. The `on_good` and `on_bad` callbacks are particularly useful for handling success/skip vs failed outcomes respectively.

```ruby
class OrderFulfillment < CMDx::Task
  def call
    validate_inventory
    process_payment
    schedule_shipping
  end
end

result = OrderFulfillmentTask.call

# Individual status callbacks
result
  .on_success { |r| schedule_delivery(r.context.order) }
  .on_skipped { |r| notify_backorder(r.context.customer) }
  .on_failed { |r| refund_payment(r.context.payment_id) }

# Outcome-based callbacks
result
  .on_good { |r| update_inventory(r.context.items) }
  .on_bad { |r| log_negative_outcome(r.metadata) }
```

## Status Metadata

> [!NOTE]
> Always include rich metadata with skip and fail operations. This information is invaluable for debugging, user feedback, and automated error handling.

### Success Metadata

```ruby
class ProcessRefund < CMDx::Task
  def call
    refund = create_refund(context.payment_id)
    context.refund_id = refund.id
    context.processed_at = Time.now
  end
end

result = ProcessRefundTask.call(payment_id: "pay_123")
result.success?  #=> true
result.metadata  #=> {} (typically empty for success)
```

### Skip Metadata

```ruby
class ProcessSubscription < CMDx::Task
  def call
    subscription = Subscription.find(context.subscription_id)

    if subscription.cancelled?
      skip!(
        Subscription already cancelled",
        cancelled_at: subscription.cancelled_at,
        skip_code: "ALREADY_CANCELLED"
      )
    end

    process_subscription(subscription)
  end
end

result = ProcessSubscriptionTask.call(subscription_id: 123)
if result.skipped?
  result.metadata[:reason]       #=> "Subscription already cancelled"
  result.metadata[:cancelled_at] #=> 2023-10-01 10:30:00 UTC
  result.metadata[:skip_code]    #=> "ALREADY_CANCELLED"
end
```

### Failure Metadata

```ruby
class ValidateUserData < CMDx::Task
  def call
    user = User.find(context.user_id)

    unless user.valid?
      fail!(
        User validation failed",
        errors: user.errors.full_messages,
        error_code: "VALIDATION_FAILED",
        retryable: false
      )
    end

    context.validated_user = user
  end
end

result = ValidateUserDataTask.call(user_id: 123)
if result.failed?
  result.metadata[:reason]      #=> "User validation failed"
  result.metadata[:errors]      #=> ["Email is invalid", "Name can't be blank"]
  result.metadata[:error_code]  #=> "VALIDATION_FAILED"
  result.metadata[:retryable]   #=> false
end
```

## Outcome-Based Logic

Statuses enable sophisticated outcome-based decision making:

### Good vs Bad Outcomes

```ruby
class EmailDelivery < CMDx::Task
  def call
    # Business logic here
    send_email
  end
end

result = EmailDeliveryTask.call

# Good outcomes (success OR skipped)
if result.good?
  # Both success and skipped are "good" outcomes
  update_user_interface(result)
  track_completion_metrics(result)
end

# Bad outcomes (skipped OR failed, excluding success)
if result.bad?
  # Handle any non-success outcome
  show_error_message(result.metadata[:reason])
  track_failure_metrics(result)
end
```

### Conditional Processing

```ruby
def process_batch_results(results)
  successful_count = results.count(&:success?)
  skipped_count = results.count(&:skipped?)
  failed_count = results.count(&:failed?)

  if results.all?(&:good?)
    mark_batch_complete
  elsif results.any?(&:failed?)
    schedule_batch_retry(results.select(&:failed?))
  end
end
```

## Status vs State vs Outcome

> [!NOTE]
> Status tracks the business outcome (how the task ended), while state tracks the execution lifecycle (where the task is). Both provide valuable but different information about task execution.

Understanding the relationship between these concepts:

- **Status**: Business execution outcome (`success`, `skipped`, `failed`)
- **State**: Technical execution lifecycle (`initialized`, `executing`, `complete`, `interrupted`)
- **Outcome**: Combined representation for unified logic

```ruby
class DataImport < CMDx::Task
  def call
    import_data
    validate_data
  end
end

result = DataImportTask.call

# Successful execution
result.state    #=> "complete" (execution finished)
result.status   #=> "success" (business outcome)
result.outcome  #=> "success" (same as status when complete)

# Skipped execution
skipped_result = DataImportTask.call(skip_import: true)
skipped_result.state    #=> "complete" (execution finished)
skipped_result.status   #=> "skipped" (business outcome)
skipped_result.outcome  #=> "skipped" (same as status)

# Failed execution
failed_result = DataImportTask.call(invalid_data: true)
failed_result.state     #=> "interrupted" (execution stopped)
failed_result.status    #=> "failed" (business outcome)
failed_result.outcome   #=> "interrupted" (reflects state for interrupted tasks)
```

## Status Serialization and Inspection

> [!IMPORTANT]
> Statuses are automatically captured in result serialization and logging. All status information persists through the complete task execution lifecycle.

```ruby
result = ProcessOrderTask.call

# Hash representation includes status
result.to_h
#=> {
#     class: "ProcessOrderTask",
#     index: 0,
#     state: "complete",
#     status: "success",
#     outcome: "success",
#     runtime: 0.045,
#     metadata: {},
#     context: { order_id: 123 }
#   }

# Human-readable inspection
result.to_s
#=> "ProcessOrderTask: type=Task index=0 state=complete status=success outcome=success runtime=0.045s"

# Chain-level status aggregation
result.chain.to_h
#=> {
#     id: "chain-550e8400-e29b-41d4-a716-446655440000",
#     state: "complete",
#     status: "success",
#     results: [
#       { state: "complete", status: "success", ... }
#     ]
#   }
```

---

- **Prev:** [Outcomes - Result](result.md)
- **Next:** [Outcomes - States](states.md)
