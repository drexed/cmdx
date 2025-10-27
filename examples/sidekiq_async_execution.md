# Sidekiq Async Execute

Execute tasks asynchronously using Sidekiq without creating separate job classes.

<https://github.com/sidekiq/sidekiq>

### Setup

```ruby
class MyTask < CMDx::Task
  include Sidekiq::Job

  def work
    # Do work...
  end

  # Use execute! to trigger Sidekiq's retry logic on failures/exceptions.
  def perform
    self.class.execute!
  end

end
```

### Usage

```ruby
MyTask.perform_async
```
