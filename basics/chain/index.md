# Basics - Chain

Chains automatically track related task executions within a thread. Think of them as execution traces that help you understand what happened and in what order.

## Management

Each thread maintains its own isolated chain using thread-local storage.

Warning

Chains are thread-local. Don't share chain references across threads—it causes race conditions.

```ruby
# Thread A
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch1.csv")
  result.chain.id    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B (completely separate chain)
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch2.csv")
  result.chain.id    #=> "z3a42b95-c821-7892-b156-dd7c921fe2a3"
end

# Access current thread's chain
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current thread's chain
```

## Links

Tasks automatically create or join the current thread's chain:

Important

Chain management is automatic—no manual lifecycle handling needed.

```ruby
class ImportDataset < CMDx::Task
  def work
    # First task creates new chain
    result1 = ValidateHeaders.execute(file_path: context.file_path)
    result1.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
    result1.chain.results.size #=> 1

    # Second task joins existing chain
    result2 = SendNotification.execute(to: "admin@company.com")
    result2.chain.id == result1.chain.id  #=> true
    result2.chain.results.size            #=> 2

    # Both results reference the same chain
    result1.chain.results == result2.chain.results #=> true
  end
end
```

## Inheritance

Subtasks automatically inherit the current thread's chain, building a unified execution trail:

```ruby
class ImportDataset < CMDx::Task
  def work
    context.dataset = Dataset.find(context.dataset_id)

    # Subtasks automatically inherit current chain
    ValidateSchema.execute
    TransformData.execute!(context)
    SaveToDatabase.execute(dataset_id: context.dataset_id)
  end
end

result = ImportDataset.execute(dataset_id: 456)
chain = result.chain

# All tasks share the same chain
chain.results.size #=> 4 (main task + 3 subtasks)
chain.results.map { |r| r.task.class }
#=> [ImportDataset, ValidateSchema, TransformData, SaveToDatabase]
```

## Structure

Chains expose comprehensive execution information:

Important

Chain state reflects the first (outermost) task result. Subtasks maintain their own states.

```ruby
result = ImportDataset.execute(dataset_id: 456)
chain = result.chain

# Chain identification
chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results #=> Array of all results in execution order

# State delegation (from first/outer-most result)
chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"

# Access individual results
chain.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class} - #{result.status}"
end
```
