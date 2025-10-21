# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `execute` and `execute!` methods. Understanding how unhandled exceptions are processed is crucial for building reliable task execution flows and implementing proper error handling strategies.

## Exception Handling

!!! warning "Important"

    When designing tasks try not to `raise` your own exceptions directly, instead use `skip!` or `fail!` to signal intent clearly.

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

!!! note

    The `exception_handler` setting only works with non-bang execution as it catches all exceptions preventing them from reaching your apps global error handler.

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
