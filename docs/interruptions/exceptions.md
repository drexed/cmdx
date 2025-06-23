# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `call` and `call!`
methods. Understanding how unhandled exceptions are processed is crucial for
building reliable task execution flows and implementing proper error handling strategies.

## Exception Handling Behavior

### Non-bang Call (`call`)

The `call` method captures **all** unhandled exceptions and converts them to
failed results, ensuring that no exceptions escape the task execution boundary.
This provides consistent, predictable behavior for result processing.

```ruby
class ProcessProblematicTask < CMDx::Task

  def call
    # This will raise a NoMethodError
    undefined_method_call
  end

end

result = ProcessProblematicTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.metadata #=> {
                #=>   reason: "[NoMethodError] undefined method `undefined_method_call`",
                #=>   original_exception: <NoMethodError>
                #=> }
```

### Exception Metadata Structure

Captured exceptions populate result metadata with structured information:

```ruby
class ProcessDatabaseTask < CMDx::Task

  def call
    # Simulate a database connection error
    raise ActiveRecord::ConnectionNotEstablished, "Database unavailable"
  end

end

result = ProcessDatabaseTask.call

# Exception information in metadata
result.metadata[:reason]             #=> "[ActiveRecord::ConnectionNotEstablished] Database unavailable"
result.metadata[:original_exception] #=> <ActiveRecord::ConnectionNotEstablished>
result.metadata[:original_exception].class #=> ActiveRecord::ConnectionNotEstablished
result.metadata[:original_exception].message #=> "Database unavailable"
result.metadata[:original_exception].backtrace #=> ["..."]
```

### Accessing Original Exception Details

```ruby
result = ProcessProblematicTask.call

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
class ProblematicTask < CMDx::Task

  def call
    # This will raise a NoMethodError directly
    undefined_method_call
  end

end

begin
  ProcessProblematicTask.call!
rescue NoMethodError => e
  puts "Caught original exception: #{e.message}"
  # Handle the original exception directly
end
```

### Fault vs Exception Behavior

```ruby
class ProcessMixedBehaviorTask < CMDx::Task

  def call
    if context.simulate_fault
      fail!("Controlled failure")  # Becomes CMDx::Failed
    else
      raise StandardError, "Uncontrolled error"  # Remains StandardError
    end
  end

end

# Fault behavior (controlled)
begin
  ProcessMixedBehaviorTask.call!(simulate_fault: true)
rescue CMDx::Failed => e
  puts "Caught CMDx fault: #{e.message}"
end

# Exception behavior (uncontrolled)
begin
  ProcessMixedBehaviorTask.call!(simulate_fault: false)
rescue StandardError => e
  puts "Caught standard exception: #{e.message}"
end
```

## Exception Classification

### Protected Exceptions

Certain CMDx-specific exceptions are always allowed to propagate and are never
converted to failed results:

```ruby
class ProcessUndefinedCallTask < CMDx::Task
  # Intentionally not implementing call method
end

# These exceptions always propagate regardless of call method
begin
  ProcessUndefinedCallTask.call
rescue CMDx::UndefinedCallError => e
  puts "This exception is never converted to a failed result"
end

begin
  ProcessUndefinedCallTask.call!
rescue CMDx::UndefinedCallError => e
  puts "This exception propagates normally in call! too"
end
```

### CMDx Fault Handling

CMDx faults have special handling in both call methods:

```ruby
class ProcessControlledFailureTask < CMDx::Task
  # Configure to halt on failures
  task_settings!(task_halt: [CMDx::Result::FAILED])

  def call
    fail!("This is a controlled failure")
  end
end

# With call - fault becomes failed result
result = ProcessControlledFailureTask.call
result.failed? #=> true

# With call! - fault becomes exception (due to task_halt configuration)
begin
  ProcessControlledFailureTask.call!
rescue CMDx::Failed => e
  puts "Fault converted to exception: #{e.message}"
end
```

## Practical Exception Handling Patterns

### Layered Exception Handling

```ruby
class ProcessRobustTask < CMDx::Task

  def call
    process_data
  rescue ActiveRecord::RecordNotFound => e
    # Handle specific database errors gracefully
    skip!("Record not found: #{e.message}")
  rescue Net::TimeoutError => e
    # Handle timeout errors as retryable failures
    fail!("Operation timed out", error_code: "TIMEOUT", retryable: true)
  rescue StandardError => e
    # Let other exceptions bubble up for automatic handling
    raise e
  end

  private

  def process_data
    # Implementation that might raise various exceptions
  end

end
```

### Exception Type-Based Processing

```ruby
def process_with_exception_analysis(task_class, **params)
  result = task_class.call(**params)

  if result.failed? && result.metadata[:original_exception]
    exception = result.metadata[:original_exception]

    case exception
    when ActiveRecord::RecordNotFound
      { status: "not_found", retryable: false }
    when Net::TimeoutError, Errno::ETIMEDOUT
      { status: "timeout", retryable: true }
    when ActiveRecord::ConnectionNotEstablished
      { status: "database_error", retryable: true }
    else
      { status: "unknown_error", retryable: false }
    end
  else
    { status: result.status, retryable: false }
  end
end
```

### Mixed Call Strategy

```ruby
class FlexibleProcessor
  def self.process_safely(task_class, **params)
    # Use call for safe processing
    result = task_class.call(**params)

    case result.status
    when "success"
      { success: true, data: result.context }
    when "skipped"
      { success: true, skipped: true, reason: result.metadata[:reason] }
    when "failed"
      if result.metadata[:original_exception]
        { success: false, exception: result.metadata[:original_exception] }
      else
        { success: false, reason: result.metadata[:reason] }
      end
    end
  end

  def self.process_with_exceptions(task_class, **params)
    # Use call! for exception-based flow
    begin
      result = task_class.call!(**params)
      { success: true, data: result.context }
    rescue CMDx::Skipped => e
      { success: true, skipped: true, reason: e.message }
    rescue CMDx::Failed => e
      { success: false, fault: e }
    rescue StandardError => e
      { success: false, exception: e }
    end
  end
end
```

## Error Recovery Patterns

### Graceful Degradation

```ruby
class IntegrateServiceTask < CMDx::Task

  def call
    primary_service_call
  rescue Net::TimeoutError => e
    # Try backup service on timeout
    backup_service_call
  rescue StandardError => e
    # Log error but don't fail the task
    logger.error "Service integration failed: #{e.message}"
    context.service_available = false
    # Task succeeds even if service fails
  end

  private

  def primary_service_call
    # Implementation
  end

  def backup_service_call
    # Fallback implementation
  end

end
```

### Exception-to-Skip Conversion

```ruby
class ProcessOptionalServiceTask < CMDx::Task

  def call
    call_external_service
  rescue Net::TimeoutError, Errno::ECONNREFUSED => e
    # Convert network errors to skips for optional services
    skip!("External service unavailable: #{e.class}")
  rescue StandardError => e
    # Other errors are real failures
    fail!("Service error: #{e.message}", original_error: e)
  end

end
```

## Best Practices

### Exception Handling Guidelines

- **Use `call` for predictable result processing** where you want to handle all outcomes uniformly
- **Use `call!` for exception-based control flow** where failures should halt execution
- **Always check for `original_exception` in metadata** when processing failed results from `call`
- **Rescue specific exception types** rather than catching all StandardError when possible
- **Convert network/timeout errors to skips** for optional operations
- **Convert validation errors to failures** with structured metadata

### Metadata Best Practices

- **Preserve original exceptions** in metadata for debugging
- **Add error codes** for programmatic error handling
- **Include retry hints** to guide retry logic
- **Provide user-friendly messages** separate from technical details

> [!NOTE]
> The `call` method ensures no exceptions escape task execution, making it ideal
> for batch processing and scenarios where you need guaranteed result objects.

> [!IMPORTANT]
> Always preserve original exception information in metadata when handling
> exceptions manually. This maintains debugging capabilities and error traceability.

---

- **Prev:** [Interruptions - Faults](https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md)
- **Next:** [Outcomes - Result](https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md)
