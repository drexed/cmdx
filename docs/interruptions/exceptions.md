# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `execute` and `execute!` methods. Understanding how unhandled exceptions are processed is crucial for building reliable task execution flows and implementing proper error handling strategies.

## Table of Contents

- [Exception Handling](#exception-handling)
  - [Non-bang execution](#non-bang-execution)
  - [Bang execution](#bang-execution)

## Exception Handling

### Non-bang execution

The `execute` method captures **all** unhandled exceptions and converts them to failed results, ensuring predictable behavior and consistent result processing.

```ruby
class ProcessPayment < CMDx::Task
  def work
    raise UnknownPaymentMethod, "unsupported payment method"
  end
end

result = ProcessPayment.execute
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.reason   #=> "[UnknownPaymentMethod] unsupported payment method"
result.cause    #=> <UnknownPaymentMethod>
```

### Bang execution

The `execute!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

```ruby
class ProcessPayment < CMDx::Task
  def work
    raise UnknownPaymentMethod, "unsupported payment method"
  end
end

begin
  ProcessPayment.execute!
rescue UnknownPaymentMethod => e
  puts "Handle exception: #{e.message}"
end
```

---

- **Prev:** [Interruptions - Faults](faults.md)
- **Next:** [Outcomes - Result](../outcomes/result.md)
