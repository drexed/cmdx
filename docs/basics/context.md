# Basics - Context

The task `context` provides flexible data storage and sharing for task objects.
Built on `LazyStruct`, context enables dynamic attribute access, parameter
validation, and seamless data flow between related tasks.

## Table of Contents

- [Loading Parameters](#loading-parameters)
- [Accessing Data](#accessing-data)
- [Modifying Context](#modifying-context)
- [Context Features](#context-features)
- [Data Sharing Between Tasks](#data-sharing-between-tasks)
- [Context Inspection](#context-inspection)

## Loading Parameters

Context is automatically populated when calling tasks with parameters. All
parameters become accessible as dynamic attributes within the task.

```ruby
ProcessUserOrderTask.call(
  user: User.first,
  order_id: 456,
  send_notification: true
)
```

## Accessing Data

Context provides multiple ways to access stored data with automatic key
normalization to symbols:

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # Method-style access (preferred)
    context.user_id           #=> 123
    context.send_notification #=> true

    # Hash-style access
    context[:order_id] #=> 456
    context["user_id"] #=> 123

    # Safe access with defaults
    context.fetch!(:priority, "normal") #=> "high"

    # Deep access for nested data
    context.dig(:metadata, :source) #=> "mobile"

    # Alias for shorter code
    ctx.user_id #=> 123 (ctx is alias for context)
  end

end
```

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # Direct assignment
    context.user = User.find(user_id)
    context.order = Order.find(order_id)
    context.processed_at = Time.now

    # Hash-style assignment
    context[:status] = "processing"
    context["result_code"] = "SUCCESS"

    # Conditional assignment
    context.notification_sent ||= false

    # Batch updates
    context.merge!(
      status: "completed",
      processed_by: current_user.id,
      completion_time: Time.now
    )

    # Removing data
    context.delete!(:temporary_data)
  end

end
```

> [!TIP]
> Use context for both input parameters and intermediate results. This creates
> a natural data flow through your task execution pipeline.

## Context Features

### Key Normalization

All keys are automatically converted to symbols for consistent access:

```ruby
SomeTask.call("user_id" => 123, :order_id => 456)

# Both accessible as symbols
context.user_id  #=> 123
context.order_id #=> 456
```

### Nil Safety

Accessing undefined attributes returns `nil` instead of raising errors:

```ruby
context.undefined_attribute #=> nil
context[:missing_key]       #=> nil
```

> [!NOTE]
> Context attributes that are **NOT** loaded will return `nil` rather than
> raising an error. This allows for graceful handling of optional parameters.

### Type Flexibility

Context accepts any data type without restrictions:

```ruby
context.string_value  = "Order processed"
context.numeric_value = 42
context.array_value   = [1, 2, 3]
context.hash_value    = { total: 99.99, currency: "USD" }
context.object_value  = User.find(123)
context.proc_value    = -> { "dynamic value" }
```

## Data Sharing Between Tasks

Context objects can be passed between tasks, enabling data flow in complex
workflows:

### Within Task Composition

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # Subtasks inherit and modify the same context
    validation_result = ValidateUserOrderTask.call(context)
    throw!(validation_result) unless validation_result.success?

    payment_result = ProcessOrderPaymentTask.call(context)
    throw!(payment_result) unless payment_result.success?

    # Context now contains data from all subtasks
    context.order_validated   #=> true (from ValidateUserOrderTask)
    context.payment_processed #=> true (from ProcessOrderPaymentTask)
  end

end
```

### After Task Completion

```ruby
# Chain task results using context
validation_result = ValidateUserOrderTask.call(user_id: 123, order_id: 456)

if validation_result.success?
  # Pass accumulated context to next task
  process_result = ProcessUserOrderTask.call(validation_result.context)

  # Continue chain with enriched context
  notification_result = SendOrderNotificationTask.call(process_result.context)
end
```

### Batch Processing

```ruby
# Context maintains continuity across batch operations
initial_context = CMDx::Context.build(
  user_id: 123,
  action: "bulk_order_processing"
)

results = [
  ValidateOrderDataTask.call(initial_context),
  ProcessOrderPaymentTask.call(initial_context),
  UpdateInventoryTask.call(initial_context)
]

# All tasks share and modify the same context data
results.first.context.validation_completed #=> true
results.last.context.inventory_updated     #=> true
```

## Context Inspection

Context provides inspection methods for debugging and logging:

```ruby
# Hash representation
context.to_h #=> { user_id: 123, order_id: 456, ... }

# Human-readable inspection
context.inspect #=> "#<CMDx::Context :user_id=123 :order_id=456>"

# Iteration
context.each_pair { |key, value| puts "#{key}: #{value}" }
```

[Learn more](../../lib/cmdx/lazy_struct.rb)
about the `LazyStruct` public API that powers context functionality.

---

- **Prev:** [Basics - Call](call.md)
- **Next:** [Basics - Chain](chain.md)
