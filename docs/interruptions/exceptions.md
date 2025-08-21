# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `execute` and `execute!` methods. Understanding how unhandled exceptions are processed is crucial for building reliable task execution flows and implementing proper error handling strategies.

## Table of Contents

- [Exception Handling](#exception-handling)
  - [Non-bang execution](#non-bang-execution)
  - [Bang execution](#bang-execution)

## Exception Handling

> [!IMPORTANT]
> When designing tasks, try not to `raise` your own exceptions directly. Instead, use skip! or fail! to signal intent clearly. skip! communicates that the task was intentionally bypassed, while fail! marks it as an expected failure with proper handling. This keeps workflows observable, predictable, and easier to debug.

### Non-bang execution

The `execute` method captures **all** unhandled exceptions and converts them to failed results, ensuring predictable behavior and consistent result processing.

```ruby
class CompressDocument < CMDx::Task
  def work
    document = Document.find(context.document_id)
    document.compress!
  end
end

result = CompressDocument.execute(document_id: "unknown-doc-id")
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.reason   #=> "[ActiveRecord::NotFoundError] record not found"
result.cause    #=> <ActiveRecord::NotFoundError>
```

### Bang execution

The `execute!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

```ruby
class CompressDocument < CMDx::Task
  def work
    document = Document.find(context.document_id)
    document.compress!
  end
end

begin
  CompressDocument.execute!(document_id: "unknown-doc-id")
rescue ActiveRecord::NotFoundError => e
  puts "Handle exception: #{e.message}"
end
```

---

- **Prev:** [Interruptions - Faults](faults.md)
- **Next:** [Outcomes - Result](../outcomes/result.md)
