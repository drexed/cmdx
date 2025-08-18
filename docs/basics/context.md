# Basics - Context

Task context provides flexible data storage, access, and sharing within task execution. It serves as the primary data container for all task inputs, intermediate results, and outputs.

## Table of Contents

- [Assigning Data](#assigning-data)
- [Accessing Data](#accessing-data)
- [Modifying Context](#modifying-context)
- [Data Sharing](#data-sharing)

## Assigning Data

Context is automatically populated with all inputs passed to a task. All keys are normalized to symbols for consistent access:

```ruby
# Direct execution
ProcessOrder.execute(user_id: 123, currency: "USD")

# Instance creation
task = ProcessOrder.new(user_id: 123, "currency" => "USD")
task.execute
```

> [!NOTE]
> String keys are automatically converted to symbols. Use symbols for consistency in your code.

## Accessing Data

Context provides multiple access patterns with automatic nil safety:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Method-style access (preferred)
    user_id = context.user_id
    amount = context.amount

    # Hash-style access
    order_id = context[:order_id]
    metadata = context["metadata"]

    # Safe access with defaults
    priority = context.fetch!(:priority, "normal")
    source = context.dig(:metadata, :source)

    # Shorter alias
    total = ctx.amount * ctx.tax_rate  # ctx aliases context
  end
end
```

> [!NOTE]
> Accessing undefined context attributes returns `nil` instead of raising errors, enabling graceful handling of optional parameters.

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Direct assignment
    context.user = User.find(context.user_id)
    context.order = Order.find(context.order_id)
    context.processed_at = Time.now

    # Hash-style assignment
    context[:status] = "processing"
    context["result_code"] = "SUCCESS"

    # Conditional assignment
    context.notification_sent ||= false

    # Batch updates
    context.merge!(
      status: "completed",
      total_amount: calculate_total,
      completion_time: Time.now
    )

    # Remove sensitive data
    context.delete!(:credit_card_number)
  end

  private

  def calculate_total
    context.amount + (context.amount * context.tax_rate)
  end
end
```

> [!TIP]
> Use context for both input parameters and intermediate results. This creates natural data flow through your task execution pipeline.

## Data Sharing

Context enables seamless data flow between related tasks in complex workflows:

```ruby
# Before and during execution
class ProcessOrder < CMDx::Task
  def work
    # Validate order data
    validation_result = ValidateOrder.execute(context)

    # Via context
    ProcessPayment.execute(context)

    # Via result
    NotifyOrderProcessed.execute(validation_result)

    # Context now contains accumulated data from all tasks
    context.order_validated    #=> true (from validation)
    context.payment_processed  #=> true (from payment)
    context.notification_sent  #=> true (from notification)
  end
end

# After execution
result = ProcessOrder.execute(order_number: 123)

ShipOrder.execute(result)
```

---

- **Prev:** [Basics - Execution](execution.md)
- **Next:** [Basics - Chain](chain.md)
