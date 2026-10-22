# Background Execution

Calling a task from a controller ties its fate to the HTTP request. When the user closes the tab, the work stops.

Push the same task onto a queue and the job backend (Sidekiq, Solid Queue, Good Job, etc.) owns retries, durability, and routing. You still write one task class — you just change *how* it gets invoked.

Two popular patterns:

- **Active Job adapter** — one generic job class runs any task by name.
- **Sidekiq on the task** — mix `Sidekiq::Job` into the task when you want queue options next to the class.

## JSON-safe context

Queues serialize arguments as JSON. Pass ids and primitives (`user_id: 42`), not live objects (`user: User.find(42)`).

Symbol keys become strings in transit; `Context.build` accepts both. Call `deep_stringify_keys` when you enqueue so `perform_now` and `perform_later` behave the same.

## Active Job adapter

Store the task **name** (a String) in the job payload so JSON serialization stays happy.

### Setup

```ruby
class TaskJob < ApplicationJob
  queue_as :default

  retry_on CMDx::Fault, wait: :polynomially_longer, attempts: 5

  def perform(task_name, context = {})
    task_class = task_name.constantize
    task_class.execute!(context) # or: execute_now!(context)
  end
end
```

```ruby
class ApplicationTask < CMDx::Task
  def self.execute_later(context = {})
    TaskJob.perform_later(name, context.deep_stringify_keys)
  end

  # Use to rehydrate objects (non-primitives)
  def self.execute_now!(context = {})
    user = User.find(context["user_id"])
    execute!(user: user, date: context["date"])
  end
end
```

```ruby
class GenerateInvoice < ApplicationTask
  required :user_id, coerce: :integer
  required :date,    coerce: :date

  def work
    context.invoice = Invoice.create!(user_id:, period_ending: date)
    InvoiceMailer.with(invoice: context.invoice).deliver_now
  end
end
```

### Usage

```ruby
GenerateInvoice.execute_later(user_id: user.id, date: Date.current)
```

## Sidekiq on the task

When the job would only instantiate the task and call it, skip the extra job file. Route through `CMDx::Runtime` inside `perform`.

### Setup

```ruby
class ProcessExport < CMDx::Task
  include Sidekiq::Job

  sidekiq_options queue: :exports, retry: 5, dead: true

  required :user_id, coerce: :integer
  required :format,  coerce: :string, validate: { inclusion: { in: %w[csv json] } }

  def work
    user = User.find(user_id)
    context.export = ExportBuilder.new(user, format:).call
    ExportMailer.with(export: context.export).ready.deliver_later
  end

  def perform(context = {})
    @context = CMDx::Context.build(context)
    CMDx::Runtime.execute(self, strict: true)
  end
end
```

### Usage

```ruby
ProcessExport.perform_async(user_id: 42, format: "csv")
ProcessExport.perform_in(1.hour, user_id: 42, format: "json")
```

## Notes

### Pick one entry point

Prefer the Active Job adapter when every task should enqueue the same way. Prefer Sidekiq on the task when only a few tasks are async and you want queue options colocated with the class.

### Sidekiq retry vs CMDx retry_on

`execute!` re-raises on failure, which triggers Sidekiq's retry. Use `retry_on` inside the task for fast in-process retries (transient socket errors). Use `sidekiq_options retry:` or Active Job `retry_on` when the process might die and you still want another attempt later.
