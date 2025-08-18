# Basics - Context

Task context provides flexible data storage, access, and sharing within task execution.

## Table of Contents

- [Context Fundamentals](#context-fundamentals)
  - [Input Loading](#input-loading)
  - [Key normalization](#input-loading)
- [Accessing Data](#accessing-data)
- [Modifying Context](#modifying-context)
- [Data Sharing Between Tasks](#data-sharing-between-tasks)
- [Result Object Context Passing](#result-object-context-passing)
- [Context Inspection and Debugging](#context-inspection-and-debugging)
- [Error Handling](#error-handling)

## Context Fundamentals

Context is automatically populated with all inputs passed to a task.

### Input Loading

Known context attributes are accessible via method and hash style accessors.
Unknown context attributes return `nil`.

```ruby
class ProcessOrder < CMDx::Task
  def call
    context.user_id   #=> 123
    context[:amount]  #=> 99.99
    context.currency  #=> nil
  end
end

ProcessOrder.call(user_id: 123, amount: 99.99)
```

### Key Normalization

All keys are automatically normalized to symbols for consistent access:

```ruby
# String and symbol keys both work
ProcessOrder.call("user_id" => 123, :amount => 99.99)

# Both accessible as symbols
context.user_id  #=> 123
context.amount   #=> 99.99
```

## Accessing Data

Context provides multiple access patterns with automatic nil safety:

```ruby
class ProcessOrder < CMDx::Task
  def call
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
> Accessing undefined attributes returns `nil` instead of raising errors, enabling graceful handling of optional parameters.

### Type Safety

Context accepts any data type without restrictions:

```ruby
context.string_value  = "Order #12345"
context.numeric_value = 42
context.array_value   = [1, 2, 3]
context.hash_value    = { total: 99.99, tax: 8.99 }
context.object_value  = User.find(123)
context.timestamp     = Time.now
```

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class ProcessOrder < CMDx::Task
  def call
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

## Data Sharing Between Tasks

Context enables seamless data flow between related tasks in complex workflows:

### Task Composition

```ruby
class ProcessOrderWorkflow < CMDx::Task
  def call
    # Validate order data
    validation_result = ValidateOrder.call(context)
    throw!(validation_result) unless validation_result.success?

    # Process payment with enriched context
    payment_result = ProcessPayment.call(context)
    throw!(payment_result) unless payment_result.success?

    # Send notifications with complete context
    NotifyOrderProcessed.call(context)

    # Context now contains accumulated data from all tasks
    context.order_validated    #=> true (from validation)
    context.payment_processed  #=> true (from payment)
    context.notification_sent  #=> true (from notification)
  end
end
```

### Workflow Chains

```ruby
# Initialize workflow context
initial_data = { user_id: 123, product_ids: [1, 2, 3] }

# Chain tasks with context flow
validation_result = ValidateCart.call(initial_data)

if validation_result.success?
  # Context accumulates data through the chain
  inventory_result = CheckInventory.call(validation_result.context)
  payment_result = ProcessPayment.call(inventory_result.context)
  shipping_result = CreateShipment.call(payment_result.context)
end
```

## Result Object Context Passing

> [!IMPORTANT]
> CMDx automatically extracts context when Result objects are passed to task methods, enabling powerful workflow compositions where task output becomes the next task's input.

```ruby
# Seamless task chaining
extraction_result = ExtractData.call(source_id: 123)
processing_result = ProcessData.call(extraction_result)

# Context flows automatically between tasks
processing_result.context.source_id         #=> 123 (from first task)
processing_result.context.extracted_records #=> [...] (from first task)
processing_result.context.processed_count   #=> 50 (from second task)
```

### Error Propagation in Chains

```ruby
# Non-raising chain with error handling
extraction_result = ExtractData.call(source_id: 123)

if extraction_result.failed?
  # Context preserved even in failure scenarios
  error_handler_result = HandleExtractionError.call(extraction_result)
  return error_handler_result
end

# Continue processing with successful result
ProcessData.call(extraction_result)
```

### Exception-Based Chains

```ruby
begin
  # Raising version propagates exceptions while preserving context
  extraction_result = ExtractData.call!(source_id: 123)
  processing_result = ProcessData.call!(extraction_result)
  notification_result = NotifyCompletion.call!(processing_result)
rescue CMDx::FailFault => e
  # Access failed task's context for error analysis
  ErrorReporting.call(
    error: e.message,
    failed_context: e.result.context,
    user_id: e.result.context.user_id
  )
end
```

## Context Inspection and Debugging

Context provides comprehensive inspection capabilities for debugging and logging:

```ruby
class Debuggable < CMDx::Task
  def call
    # Log current context state
    Rails.logger.info "Context: #{context.inspect}"

    # Convert to hash for serialization
    context_data = context.to_h
    #=> { user_id: 123, amount: 99.99, status: "processing" }

    # Iterate over context data
    context.each_pair do |key, value|
      puts "#{key}: #{value.class} = #{value}"
    end

    # Check for specific keys
    has_user = context.key?(:user_id)     #=> true
    has_admin = context.key?(:admin_mode) #=> false
  end
end
```

### Production Logging

```ruby
class OrderProcessing < CMDx::Task
  def call
    log_context_snapshot("start")

    process_order

    log_context_snapshot("complete")
  end

  private

  def log_context_snapshot(stage)
    Rails.logger.info({
      stage: stage,
      task: self.class.name,
      context: context.to_h.except(:sensitive_data)
    }.to_json)
  end
end
```

## Error Handling

> [!WARNING]
> Context operations are generally safe, but understanding error scenarios helps build robust applications.

### Safe Access Patterns

```ruby
class Robust < CMDx::Task
  def call
    # Safe: returns nil for missing attributes
    user_id = context.user_id || 'anonymous'

    # Safe: fetch with default
    timeout = context.fetch!(:timeout, 30)

    # Safe: deep access with nil protection
    api_key = context.dig(:credentials, :api_key)

    # Safe: conditional assignment
    context.processed_at ||= Time.now
  end
end
```

### Common Error Scenarios

```ruby
# Missing required context data
class Payment < CMDx::Task
  def call
    # Check for required context before proceeding
    unless context.user_id && context.amount
      context.error_message = "Missing required payment data"
      fail!(Cannot process payment")
    end

    process_payment
  end
end

# Invalid context modifications
class Validation < CMDx::Task
  def call
    # Context cannot be replaced entirely
    # context = {} # This won't work as expected

    # Instead, clear individual keys or use merge!
    context.delete!(:temporary_data)
    context.merge!(validation_status: "complete")
  end
end
```

> [!TIP]
> Use context inspection methods liberally during development and testing. The `to_h` method is particularly useful for logging and debugging complex workflows.

[Learn more](../../lib/cmdx/lazy_struct.rb) about the `LazyStruct` implementation that powers context functionality.

---

- **Prev:** [Basics - Execution](execution.md)
- **Next:** [Basics - Chain](chain.md)
