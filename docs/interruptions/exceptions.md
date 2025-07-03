# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `call` and `call!`
methods. Understanding how unhandled exceptions are processed is crucial for
building reliable task execution flows and implementing proper error handling strategies.

## Table of Contents

- [Exception Handling Behavior](#exception-handling-behavior)
- [Bang Call (`call!`)](#bang-call-call)
- [Exception Classification](#exception-classification)

## Exception Handling Behavior

### Non-bang Call (`call`)

The `call` method captures **all** unhandled exceptions and converts them to
failed results, ensuring that no exceptions escape the task execution boundary.
This provides consistent, predictable behavior for result processing.

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # This will raise a NoMethodError
    undefined_method_call
  end

end

result = ProcessUserOrderTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.metadata #=> {
                #=>   reason: "[NoMethodError] undefined method `undefined_method_call`",
                #=>   original_exception: <NoMethodError>
                #=> }
```

> [!NOTE]
> The `call` method ensures no exceptions escape task execution, making it ideal
> for workflow processing and scenarios where you need guaranteed result objects.

### Exception Metadata Structure

Captured exceptions populate result metadata with structured information:

```ruby
class ConnectDatabaseTask < CMDx::Task

  def call
    # Simulate a database connection error
    raise ActiveRecord::ConnectionNotEstablished, "Database unavailable"
  end

end

result = ConnectDatabaseTask.call

# Exception information in metadata
result.metadata[:reason]                       #=> "[ActiveRecord::ConnectionNotEstablished] Database unavailable"
result.metadata[:original_exception]           #=> <ActiveRecord::ConnectionNotEstablished>
result.metadata[:original_exception].class     #=> ActiveRecord::ConnectionNotEstablished
result.metadata[:original_exception].message   #=> "Database unavailable"
result.metadata[:original_exception].backtrace #=> ["..."]
```

### Accessing Original Exception Details

```ruby
result = ProcessUserOrderTask.call

if result.failed? && result.metadata[:original_exception]
  original = result.metadata[:original_exception]

  puts "Exception type: #{original.class}"
  puts "Exception message: #{original.message}"
  puts "Exception backtrace:"
  puts original.backtrace.first(5).join("\n")

  # Check exception type for specific handling
  case original
  when ActiveRecord::RecordNotFound
    handle_missing_record(original)
  when Net::TimeoutError
    handle_timeout_error(original)
  when StandardError
    handle_generic_error(original)
  end
end
```

## Bang Call (`call!`)

The `call!` method allows unhandled exceptions to propagate **unless** they are
CMDx faults that match the `task_halt` configuration. This enables exception-based
control flow while still providing structured fault handling.

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    # This will raise a NoMethodError directly
    undefined_method_call
  end

end

begin
  ProcessUserOrderTask.call!
rescue NoMethodError => e
  puts "Caught original exception: #{e.message}"
  # Handle the original exception directly
end
```

### Fault vs Exception Behavior

```ruby
class ProcessOrderPaymentTask < CMDx::Task

  def call
    if context.simulate_fault
      fail!(reason: "Controlled failure") # Becomes CMDx::Failed
    else
      raise StandardError, "Uncontrolled error" # Remains StandardError
    end
  end

end

# Fault behavior (controlled)
begin
  ProcessOrderPaymentTask.call!(simulate_fault: true)
rescue CMDx::Failed => e
  puts "Caught CMDx fault: #{e.message}"
end

# Exception behavior (uncontrolled)
begin
  ProcessOrderPaymentTask.call!(simulate_fault: false)
rescue StandardError => e
  puts "Caught standard exception: #{e.message}"
end
```

## Exception Classification

### Protected Exceptions

Certain CMDx-specific exceptions are always allowed to propagate and are never
converted to failed results:

```ruby
class ProcessUndefinedOrderTask < CMDx::Task
  # Intentionally not implementing call method
end

# These exceptions always propagate regardless of call method
begin
  ProcessUndefinedOrderTask.call
rescue CMDx::UndefinedCallError => e
  puts "This exception is never converted to a failed result"
end

begin
  ProcessUndefinedOrderTask.call!
rescue CMDx::UndefinedCallError => e
  puts "This exception propagates normally in call! too"
end
```

### CMDx Fault Handling

CMDx faults have special handling in both call methods:

```ruby
class ProcessOrderWithHaltTask < CMDx::Task
  # Configure to halt on failures
  task_settings!(task_halt: [CMDx::Result::FAILED])

  def call
    fail!(reason: "This is a controlled failure")
  end
end

# With call - fault becomes failed result
result = ProcessOrderWithHaltTask.call
result.failed? #=> true

# With call! - fault becomes exception (due to task_halt configuration)
begin
  ProcessOrderWithHaltTask.call!
rescue CMDx::Failed => e
  puts "Fault converted to exception: #{e.message}"
end
```

> [!IMPORTANT]
> Always preserve original exception information in metadata when handling
> exceptions manually. This maintains debugging capabilities and error traceability.

## Practical Exception Handling Patterns

### Layered Exception Handling

```ruby
class ProcessUserOrderTask < CMDx::Task

  def call
    process_order_data
  rescue ActiveRecord::RecordNotFound => e
    # Handle specific database errors gracefully
    skip!(reason: "Order not found: #{e.message}")
  rescue Net::TimeoutError => e
    # Handle timeout errors as retryable failures
    fail!(reason: "Order processing timed out", error_code: "TIMEOUT", retryable: true)
  rescue StandardError => e
    # Let other exceptions bubble up for automatic handling
    raise e
  end

  private

  def process_order_data
    # Implementation that might raise various exceptions
  end

end
```

> [!WARNING]
> The `call!` method allows exceptions to propagate, which can interrupt execution flow. Use it only when you want exception-based control flow or need to handle specific errors at a higher level.

---

- **Prev:** [Interruptions - Faults](faults.md)
- **Next:** [Outcomes - Result](../outcomes/result.md)
