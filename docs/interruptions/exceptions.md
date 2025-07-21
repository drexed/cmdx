# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `call` and `call!` methods. Understanding how unhandled exceptions are processed is crucial for building reliable task execution flows and implementing proper error handling strategies.

## Table of Contents

- [TLDR](#tldr)
- [Exception Handling Methods](#exception-handling-methods)
- [Exception Metadata](#exception-metadata)
- [Bang Call Behavior](#bang-call-behavior)
- [Exception Classification](#exception-classification)
- [Error Handling Patterns](#error-handling-patterns)

## TLDR

```ruby
# Non-bang call - captures ALL exceptions
result = ProcessOrderTask.call     # Never raises, always returns result
result.failed?                     # true if exception occurred
result.metadata[:original_exception] # Access original exception

# Bang call - lets exceptions propagate
ProcessOrderTask.call!             # Raises exceptions (except configured faults)

# Exception info always available in metadata
result.metadata[:reason]           # Human-readable error message
result.metadata[:original_exception] # Original exception object
```

## Exception Handling Methods

> [!IMPORTANT]
> The key difference: `call` guarantees a result object, while `call!` allows exceptions to propagate for standard error handling patterns.

### Non-bang Call (`call`)

The `call` method captures **all** unhandled exceptions and converts them to failed results, ensuring predictable behavior and consistent result processing.

| Behavior | Description |
|----------|-------------|
| **Exception Capture** | All exceptions caught and converted |
| **Return Value** | Always returns a result object |
| **State** | `"interrupted"` for exception failures |
| **Status** | `"failed"` for all captured exceptions |
| **Metadata** | Exception details preserved |

```ruby
class ProcessPaymentTask < CMDx::Task
  def call
    raise ActiveRecord::RecordNotFound, "Payment method not found"
  end
end

result = ProcessPaymentTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
```

### Bang Call (`call!`)

The `call!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

```ruby
class ProcessPaymentTask < CMDx::Task
  def call
    raise StandardError, "Payment gateway unavailable"
  end
end

begin
  ProcessPaymentTask.call!
rescue StandardError => e
  puts "Handle exception: #{e.message}"
end
```

## Exception Metadata

> [!NOTE]
> Exception information is preserved in result metadata, providing full debugging context while maintaining clean result interfaces.

### Metadata Structure

```ruby
result = ProcessPaymentTask.call

# Exception metadata always includes:
result.metadata[:reason]                  #=> "[StandardError] Payment gateway unavailable"
result.metadata[:original_exception]      #=> <StandardError instance>

# Access original exception properties
exception = result.metadata[:original_exception]
exception.class                          #=> StandardError
exception.message                        #=> "Payment gateway unavailable"
exception.backtrace                      #=> ["lib/tasks/payment.rb:15:in `call'", ...]
```

### Exception Type Checking

```ruby
class DatabaseTask < CMDx::Task
  def call
    raise ActiveRecord::ConnectionNotEstablished, "Database unavailable"
  end
end

result = DatabaseTask.call

if result.failed? && result.metadata[:original_exception]
  case result.metadata[:original_exception]
  when ActiveRecord::ConnectionNotEstablished
    retry_with_fallback_database
  when Net::TimeoutError
    retry_with_increased_timeout
  when StandardError
    log_and_alert_administrators
  end
end
```

## Bang Call Behavior

> [!WARNING]
> `call!` propagates exceptions immediately, bypassing result object creation. Only use when you need direct exception handling or integration with exception-based error handling systems.

### Fault vs Exception Handling

CMDx faults receive special treatment based on `task_halt` configuration:

```ruby
class ProcessOrderTask < CMDx::Task
  cmd_settings!(task_halt: [CMDx::Result::FAILED])

  def call
    if context.payment_invalid
      fail!(reason: "Invalid payment method")  # CMDx fault
    else
      raise StandardError, "System error"     # Regular exception
    end
  end
end

# Fault behavior (converted to exception due to task_halt)
begin
  ProcessOrderTask.call!(payment_invalid: true)
rescue CMDx::Failed => e
  puts "Controlled fault: #{e.message}"
end

# Exception behavior (propagates normally)
begin
  ProcessOrderTask.call!(payment_invalid: false)
rescue StandardError => e
  puts "System exception: #{e.message}"
end
```

## Exception Classification

### Protected Exceptions

> [!IMPORTANT]
> CMDx framework exceptions always propagate regardless of call method, ensuring framework integrity and proper error reporting.

Certain exceptions are never converted to failed results:

```ruby
class InvalidTask < CMDx::Task
  # Intentionally not implementing call method
end

# Framework exceptions always propagate
begin
  InvalidTask.call  # Even non-bang call propagates framework exceptions
rescue CMDx::UndefinedCallError => e
  puts "Framework exception: #{e.message}"
end
```

### Exception Hierarchy

| Exception Type | `call` Behavior | `call!` Behavior |
|----------------|-----------------|------------------|
| **CMDx Framework** | Propagates | Propagates |
| **CMDx Faults** | Converts to result | Respects `task_halt` config |
| **Standard Exceptions** | Converts to result | Propagates |
| **Custom Exceptions** | Converts to result | Propagates |

## Error Handling Patterns

### Graceful Degradation

```ruby
class ProcessUserDataTask < CMDx::Task
  def call
    user_data = fetch_user_data
    process_data(user_data)
  end

  private

  def fetch_user_data
    # May raise various exceptions
    external_api.get_user_data(context.user_id)
  end
end

# Handle with graceful degradation
result = ProcessUserDataTask.call(user_id: 12345)

if result.failed?
  case result.metadata[:original_exception]
  when Net::TimeoutError
    # Retry with cached data
    fallback_processor.process_cached_data(user_id)
  when JSON::ParserError
    # Handle malformed response
    error_reporter.log_api_format_error
  else
    # Generic error handling
    notify_administrators(result.metadata[:reason])
  end
end
```

> [!TIP]
> Use `call` for workflow processing where you need guaranteed result objects, and `call!` for direct integration with existing exception-based error handling patterns.

---

- **Prev:** [Interruptions - Faults](faults.md)
- **Next:** [Outcomes - Result](../outcomes/result.md)
