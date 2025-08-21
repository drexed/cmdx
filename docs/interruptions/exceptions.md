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
class ProcessDocument < CMDx::Task
  def work
    raise UnsupportedFormat, "document format not supported"
  end
end

result = ProcessDocument.execute
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.reason   #=> "[UnsupportedFormat] document format not supported"
result.cause    #=> <UnsupportedFormat>
```

### Bang execution

The `execute!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

```ruby
class ProcessDocument < CMDx::Task
  def work
    raise UnsupportedFormat, "document format not supported"
  end
end

begin
  ProcessDocument.execute!
rescue UnsupportedFormat => e
  puts "Handle exception: #{e.message}"
end
```

---

- **Prev:** [Interruptions - Faults](faults.md)
- **Next:** [Outcomes - Result](../outcomes/result.md)
