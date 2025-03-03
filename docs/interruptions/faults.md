# Interruptions - Faults

Faults are the mechanisms by which `CMDx` goes about halting execution of tasks
via the `skip!` and `fail!` methods. When tasks are executed with bang `call!` method,
a fault exception that matches the current task status will be raised.

## Rescue

Use the standard Ruby `rescue` method to handle any faults with custom logic.

```ruby
begin
  ProcessOrderTask.call!
rescue CMDx::Skipped
  # Do work on any skipped tasks
rescue CMDx::Failed
  # Do work on any failed tasks
rescue CMDx::Fault
  # Do work on any skipped or failed tasks
end
```

## For

Faults can be matched for the task that caused it.

```ruby
begin
  ProcessOrderTask.call!
rescue CMDx::Skipped.for?(ProcessOrderTask, DeliverOrderTask)
  # Do work on just skipped ProcessOrderTask or DeliverOrderTask tasks
end
```

## Matches

Faults allow advance rescue matching with access to the underlying task internals.

```ruby
begin
  ProcessOrderTask.call!
rescue CMDx::Fault.matches? { |f| f.result.metadata[:reason].includes?("out of stock") }
  # Do work on any skipped or failed tasks that have `:reason` metadata equals "out of stock"
end
```

> [!IMPORTANT]
> All fault exceptions have access to the `for?` and `matches?` methods.

## Throw

Throw the result of subtasks to bubble up fault as its own. Throwing will use the
subtask results' status and metadata to create a matching halt on the parent task.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    throw!(SendConfirmationNotificationsTask.call)

    # Do other work...
  end

end

result = ProcessOrderTask.call
result.state    #=> "interrupted"
result.status   #=> "skipped"
result.metadata #=> { reason: "Order confirmation could not be sent due to invalid email." }
```

> [!NOTE]
> `throw!` will bubble any skipped and failed results. To only throw skipped results, just add
> a conditional for the specific status.

## Results

The following represents a result output example of a thrown fault.

```ruby
result = ProcessOrderTask.call
result.threw_failure  #=> <CMDx::Result[SendConfirmationNotificationsTask] ...>
result.caused_failure #=> <CMDx::Result[DeliverEmailTask] ...>
```

---

- **Prev:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
- **Next:** [Interruptions - Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
