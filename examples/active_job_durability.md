# Active Job Durability

A task invoked from a controller dies with the request. Routing it through Active Job hands durability, retries, and queue routing to the queue backend (Sidekiq, Solid Queue, GoodJob), so a transient failure becomes a retried job instead of a 500.

## Setup

A single adapter job runs any task class. Storing the task name (a String) keeps the payload safe under JSON serialization.

```ruby
# app/jobs/task_job.rb
# frozen_string_literal: true

class TaskJob < ApplicationJob
  queue_as :default

  retry_on CMDx::Fault, wait: :polynomially_longer, attempts: 5

  def perform(task_name, context = {})
    task_class = task_name.constantize
    task_class.execute!(context)
  end
end
```

A base class exposes the enqueue helper so every task gets it for free.

```ruby
# app/tasks/application_task.rb
# frozen_string_literal: true

class ApplicationTask < CMDx::Task
  def self.perform_later(context = {})
    TaskJob.perform_later(name, context.deep_stringify_keys)
  end
end
```

## Usage

```ruby
class GenerateInvoice < ApplicationTask
  required :user_id, coerce: :integer
  required :date,    coerce: :date

  def work
    context.invoice = Invoice.create!(user_id:, period_ending: date)
    InvoiceMailer.with(invoice: context.invoice).deliver_now
  end
end

GenerateInvoice.perform_later(user_id: user.id, date: Date.current)
```

## Notes

!!! warning "Symbol vs String keys"

    Active Job serializes arguments as JSON, so symbols round-trip as strings. `Context.build` accepts either, but `deep_stringify_keys` on enqueue removes the asymmetry between `perform_now` and `perform_later`.
