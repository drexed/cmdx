# Basics - Context

The task `context` provides flexible data storage and sharing for task objects.
Built on `LazyStruct`, context enables dynamic attribute access, parameter
validation, and seamless data flow between related tasks.

## Loading Parameters

Context is automatically populated when calling tasks with parameters. All
parameters become accessible as dynamic attributes within the task.

```ruby
ProcessOrderTask.call(
  order_id: 123,
  notify_customer: true,
  metadata: { source: "web", priority: "high" }
)
```

## Accessing Data

Context provides multiple ways to access stored data with automatic key
normalization to symbols:

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Method-style access (preferred)
    context.order_id       #=> 123
    context.notify_customer #=> true

    # Hash-style access
    context[:order_id]     #=> 123
    context["order_id"]    #=> 123

    # Safe access with defaults
    context.fetch!(:priority, "normal") #=> "high"

    # Deep access for nested data
    context.dig(:metadata, :source)     #=> "web"

    # Alias for shorter code
    ctx.order_id           #=> 123 (ctx is alias for context)
  end

end
```

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Direct assignment
    context.order = Order.find(order_id)
    context.processed_at = Time.current

    # Hash-style assignment
    context[:status] = "processing"
    context["result_code"] = "OK"

    # Conditional assignment
    context.notification_sent ||= false

    # Batch updates
    context.merge!(
      status: "complete",
      processed_by: current_user.id,
      completion_time: Time.current
    )

    # Removing data
    context.delete!(:temporary_data)
  end

end
```

## Context Features

### Key Normalization

All keys are automatically converted to symbols for consistent access:

```ruby
task.call("order_id" => 123, :customer_id => 456)

# Both accessible as symbols
context.order_id    #=> 123
context.customer_id #=> 456
```

### Nil Safety

Accessing undefined attributes returns `nil` instead of raising errors:

```ruby
context.undefined_attribute #=> nil
context[:missing_key]       #=> nil
```

### Type Flexibility

Context accepts any data type without restrictions:

```ruby
context.string_value  = "text"
context.numeric_value = 42
context.array_value   = [1, 2, 3]
context.hash_value    = { a: 1, b: 2 }
context.object_value  = User.new
context.proc_value    = -> { "dynamic" }
```

## Data Sharing Between Tasks

Context objects can be passed between tasks, enabling data flow in complex
workflows:

### Within Task Composition

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Subtasks inherit and modify the same context
    validation_result = ValidateOrderTask.call(context)
    throw!(validation_result) unless validation_result.success?

    payment_result = ProcessPaymentTask.call(context)
    throw!(payment_result) unless payment_result.success?

    # Context now contains data from all subtasks
    context.order_validated  #=> true (from ValidateOrderTask)
    context.payment_processed #=> true (from ProcessPaymentTask)
  end

end
```

### After Task Completion

```ruby
# Chain task results using context
validation_result = ValidateOrderTask.call(order_id: 123)

if validation_result.success?
  # Pass accumulated context to next task
  process_result = ProcessOrderTask.call(validation_result.context)

  # Continue chain with enriched context
  notification_result = NotifyCustomerTask.call(process_result.context)
end
```

### Batch Processing

```ruby
# Context maintains continuity across batch operations
initial_context = CMDx::Context.build(
  user_id: 123,
  action: "bulk_process"
)

results = [
  ProcessTask1.call(initial_context),
  ProcessTask2.call(initial_context),
  ProcessTask3.call(initial_context)
]

# All tasks share and modify the same context data
results.first.context.task1_completed  #=> true
results.last.context.task3_result       #=> "final result"
```

## Context Inspection

Context provides inspection methods for debugging and logging:

```ruby
# Hash representation
context.to_h #=> { order_id: 123, customer_id: 456, ... }

# Human-readable inspection
context.inspect #=> "#<CMDx::Context :order_id=123 :customer_id=456>"

# Iteration
context.each_pair { |key, value| puts "#{key}: #{value}" }
```

## Advanced Features

### Context Building

Create contexts explicitly using the factory method:

```ruby
# From hash
context = CMDx::Context.build(name: "John", age: 30)

# From existing context (reuses unfrozen, creates new if frozen)
new_context = CMDx::Context.build(existing_context)

# From any hash-like object
params = ActionController::Parameters.new(data: "value")
context = CMDx::Context.build(params.permit(:data))
```

### Comparison and Equality

```ruby
context1 = CMDx::Context.build(a: 1, b: 2)
context2 = CMDx::Context.build(a: 1, b: 2)

context1 == context2  #=> true
context1.eql?(context2) #=> true
```

## Best Practices

### Context Usage

- **Use parameter delegation** for frequently accessed parameters
- **Leverage context for data flow** between related tasks
- **Store intermediate results** in context for debugging and chaining
- **Use consistent naming** for context attributes across related tasks

### Data Management

- **Keep context focused** on task-relevant data
- **Clean up temporary data** when no longer needed
- **Use structured data** for complex information
- **Document context expectations** for complex workflows

### Debugging and Monitoring

- **Use `to_h` for logging** context state at key points
- **Leverage run tracking** for workflow monitoring
- **Include context in error reports** for better debugging
- **Use consistent context patterns** across similar tasks

> [!NOTE]
> Context attributes that are **NOT** loaded will return `nil` rather than
> raising an error. This allows for graceful handling of optional parameters.

> [!TIP]
> Use context for both input parameters and intermediate results. This creates
> a natural data flow through your task execution pipeline.

[Learn more](https://github.com/drexed/cmdx/blob/main/lib/cmdx/lazy_struct.rb)
about the `LazyStruct` public API that powers context functionality.

---

- **Prev:** [Basics - Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
- **Next:** [Basics - Run](https://github.com/drexed/cmdx/blob/main/docs/basics/run.md)
