# Exceptions Reference

CMDx defines a clear exception hierarchy for distinguishing between different failure types. Understanding this hierarchy is essential for writing correct `rescue` clauses.

## Hierarchy

```
StandardError
└── CMDx::Error (alias: CMDx::Exception)
    ├── CMDx::CoercionError
    ├── CMDx::DeprecationError
    ├── CMDx::UndefinedMethodError
    ├── CMDx::ValidationError
    └── CMDx::Fault
        ├── CMDx::SkipFault
        └── CMDx::FailFault

Interrupt
└── CMDx::TimeoutError
```

## Exception Types

### CMDx::Error

Base class for all CMDx exceptions. Also aliased as `CMDx::Exception`.

```ruby
rescue CMDx::Error => e
  # Catches any CMDx-specific error
end
```

### CMDx::CoercionError

Raised internally when a type coercion fails. Custom coercions must raise this to integrate with CMDx's error reporting.

```ruby
class MoneyCoercion
  def self.call(value, options = {})
    Money.parse(value)
  rescue ArgumentError
    raise CMDx::CoercionError, "could not convert into money"
  end
end
```

### CMDx::ValidationError

Raised internally when a custom validator rejects a value. Custom validators must raise this to integrate with CMDx's error reporting.

```ruby
class PhoneValidator
  def self.call(value, options = {})
    unless value.match?(/\A\+?[\d\s\-()]+\z/)
      raise CMDx::ValidationError, "is not a valid phone number"
    end
  end
end
```

### CMDx::DeprecationError

Raised when a task with `settings(deprecate: :raise)` is executed. See [Deprecation](deprecation.md).

```ruby
begin
  LegacyTask.execute(data: payload)
rescue CMDx::DeprecationError => e
  puts "Task prohibited: #{e.message}"
end
```

### CMDx::UndefinedMethodError

Raised when a task is executed without defining a `work` method.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method
end

IncompleteTask.execute #=> raises CMDx::UndefinedMethodError
```

### CMDx::Fault

Base class for execution interruptions raised by `execute!`. All faults carry a `result` with full execution context. See [Faults](interruptions/faults.md) for advanced matching.

| Subclass | Triggered By | Raised When |
|----------|--------------|-------------|
| `CMDx::SkipFault` | `skip!` | Task was intentionally skipped |
| `CMDx::FailFault` | `fail!`, validation errors, exceptions | Task execution failed |

```ruby
begin
  MyTask.execute!(args)
rescue CMDx::FailFault => e
  e.result    #=> CMDx::Result with full execution data
  e.task      #=> The task instance
  e.context   #=> Task context
  e.chain     #=> Execution chain
rescue CMDx::SkipFault => e
  e.result.reason #=> "Reason for skipping"
rescue CMDx::Fault => e
  # Catch-all for any interruption
end
```

### CMDx::TimeoutError

Raised by the [Timeout middleware](middlewares.md#timeout) when a task exceeds its time limit.

!!! danger "Caution"

    `TimeoutError` inherits from `Interrupt`, **not** `StandardError`. This means `rescue StandardError` will **not** catch timeouts. You must rescue `CMDx::TimeoutError` or `Interrupt` explicitly.

```ruby
begin
  SlowTask.execute!(data: large_dataset)
rescue CMDx::TimeoutError => e
  puts "Task timed out: #{e.message}"
rescue CMDx::FailFault => e
  # Timeouts caught by `execute` are wrapped in a FailFault
  puts "Task failed: #{e.result.reason}"
end
```

!!! note

    When using non-bang `execute`, timeouts are caught internally and converted to a failed result. The `TimeoutError` distinction matters primarily for `execute!` or custom middleware error handling.
