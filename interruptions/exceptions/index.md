# Interruptions - Exceptions

Exception handling differs between `execute` and `execute!`. Choose the method that matches your error handling strategy.

## Exception Handling

!!! warning "Important"

    Prefer `skip!` and `fail!` over raising exceptions—they signal intent more clearly.

### Non-bang execution

Captures all exceptions and returns them as failed results:

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

    Use `exception_handler` with `execute` to send exceptions to APM tools before they become failed results.

### Bang execution

Lets exceptions propagate naturally for standard Ruby error handling:

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
