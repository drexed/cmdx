# Active Job Durability

Execute CMDx tasks reliably in the background by routing them through Active Job, so your queue backend (Sidekiq, Solid Queue, etc.) handles durability and retries.

## Setup

A generic adapter job wraps any task name + context pair:

```ruby
# app/jobs/task_job.rb
class TaskJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(task_name, context = {})
    result = task_name.constantize.execute(context)
    raise result.cause if result.failed? && result.cause
  end
end
```

Extend your base task to expose an enqueue helper:

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  def self.perform_later(**attributes)
    TaskJob.perform_later(name, attributes)
  end
end
```

## Usage

```ruby
GenerateInvoice.perform_later(user_id: user.id, date: Date.today)
```

## Notes

!!! note

    `wait: :polynomially_longer` is the Rails 7.1+ default; earlier releases used `:exponentially_longer`.

!!! tip

    Re-raising `result.cause` lets Active Job's `retry_on` see the original exception. A task that finishes as `failed` via `fail!` (no `cause`) will not retry — inspect `result.reason` / `result.metadata` from an `on_failed` callback or a `:task_executed` telemetry subscriber instead.
