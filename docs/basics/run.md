# Basics - Run

A run represents a group of tasks executed as part of collection.

When building complex tasks, it's best to pass the parents context to subtasks
(unless necessary or preventative) so that it gains automated indexing and the
parents `run_id`. This makes it easy to identify all tasks involved in one
execution from logging and stdout console calls.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Subtasks inherit the ProcessOrderTask run_id:
    SendEmailConfirmationTask.call(context)
    NotifyPartnerWarehousesTask.call(context)
  end

end

result = ProcessOrderTask.call
puts result.run.to_s

#   Task name                     Index   Run ID      Task ID   etc
# -----------------------------------------------------------------
#=> ProcessOrderTask              0       foobar123   abc123    ...
#=> SendEmailConfirmationTask     1       foobar123   def456    ...
#=> NotifyPartnerWarehousesTask   2       foobar123   ghi789    ...
```

---

- **Prev:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
- **Next:** [Interruptions - Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
