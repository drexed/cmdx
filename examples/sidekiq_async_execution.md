# Sidekiq Async Execution

Most tasks that need to run asynchronously don't deserve their own job class — the job would just instantiate the task and call it. Mixing `Sidekiq::Job` directly into the task collapses both into one file and reuses Sidekiq's queue routing, retry, and dead-set machinery as-is.

## Setup

```ruby
# app/tasks/process_export.rb
# frozen_string_literal: true

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

## Usage

```ruby
ProcessExport.perform_async(user_id: 42, format: "csv")
ProcessExport.perform_in(1.hour, user_id: 42, format: "json")
```

## Notes

!!! note "Two task instances"

    Sidekiq instantiates the class to call `#perform`; that instance forwards to `self.class.execute!`, which builds a *fresh* task with its own context and runs the full lifecycle. The Sidekiq instance is throwaway — declarations (`required`, `register`, callbacks) take effect on the second instance.

!!! warning "JSON-safe arguments"

    Sidekiq serializes payloads as JSON, so every value in the context must round-trip through `JSON.dump`/`JSON.parse`. Pass `user_id: 42`, never `user: User.find(42)`. Symbol keys deserialize as strings — `Context.build` accepts both, but consider `deep_stringify_keys` at the call site to make the asymmetry explicit.

!!! tip "Sidekiq retry vs CMDx retry_on"

    `execute!` re-raises on failure, which triggers Sidekiq's `sidekiq_retry`. Use `retry_on` inside the task for fast in-process retries (transient socket errors), and rely on `sidekiq_options retry:` for slow durable retries that survive a process restart.
