# Sidekiq Async Execution

Run tasks asynchronously via [Sidekiq](https://github.com/sidekiq/sidekiq) without defining a separate job class.

## Setup

```ruby
class ProcessExport < CMDx::Task
  include Sidekiq::Job

  required :user_id

  def work
    # ...
  end

  def perform(context = {})
    self.class.execute!(context)
  end
end
```

## Usage

```ruby
ProcessExport.perform_async(user_id: 42)
```

## Notes

!!! note

    Sidekiq instantiates the class to call `#perform`, which then forwards to `self.class.execute!(context)` — that's a fresh task instance running the full CMDx lifecycle. `execute!` re-raises on failure, which triggers Sidekiq's `sidekiq_retry` machinery.

!!! warning "Important"

    Sidekiq serializes arguments as JSON, so every value in `context` must round-trip through `JSON.dump` — pass `user_id: 42`, not `user: User.find(42)`.
