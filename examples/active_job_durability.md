# Active Job Durability

Execute tasks reliably in the background using Active Job to ensure durability and handle retries.

### Adapter Pattern

Create a generic job to wrap task execution:

```ruby
class TaskJob < ApplicationJob
  queue_as :default

  # Configure retry policy for durability
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(task_name, context = {})
    # 1. Resolve the task class
    task = task_name.constantize

    # 2. Execute the task
    result = task.execute(context)

    # 3. Handle failures
    # Raise an exception to trigger Active Job's retry mechanism
    # if the task failed unexpectedly.
    raise result.cause if result.failure?
  end
end
```

### Integration

Extend your base task to support background execution:

```ruby
class ApplicationTask < CMDx::Task
  # Enqueue the task to be performed later
  def self.perform_later(**attributes)
    TaskJob.perform_later(name, attributes)
  end
end
```

### Usage

Execute any task asynchronously with full durability:

```ruby
# The task will be serialized, persisted to Redis/DB, and retried on failure
GenerateInvoice.perform_later(user_id: user.id, date: Date.today)
```
