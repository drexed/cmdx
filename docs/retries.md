# Retries

CMDx provides automatic retry functionality for tasks that encounter transient failures. This is essential for handling temporary issues like network timeouts, rate limits, or database locks without manual intervention.

## Basic Usage

Configure retries upto n attempts without any delay.

```ruby
class FetchExternalData < CMDx::Task
  settings retries: 3

  def work
    response = HTTParty.get("https://api.example.com/data")
    context.data = response.parsed_response
  end
end
```

When an exception occurs during execution, CMDx automatically retries up to the configured limit.

## Selective Retries

By default, CMDx retries on `StandardError` and its subclasses. Narrow this to specific exception types:

```ruby
class ProcessPayment < CMDx::Task
  settings retries: 5, retry_on: [Stripe::RateLimitError, Net::ReadTimeout]

  def work
    # Your logic here...
  end
end
```

!!! warning "Important"

    Only exceptions matching the `retry_on` configuration will trigger retries. Uncaught exceptions immediately fail the task.

## Retry Jitter

Add delays between retry attempts to avoid overwhelming external services or to implement exponential backoff strategies.

### Fixed Value

Use a numeric value to calculate linear delay (`jitter * current_retry`):

```ruby
class ImportRecords < CMDx::Task
  # Fixed
  settings retries: 3, retry_jitter: 0.5

  def work
    # Delays: 0s, 0.5s (retry 1), 1.0s (retry 2), 1.5s (retry 3)
    context.records = ExternalAPI.fetch_records
  end
end
```

### Symbol References

Define an instance method for custom delay logic:

```ruby
class SyncInventory < CMDx::Task
  settings retries: 5, retry_jitter: :exponential_backoff

  def work
    context.inventory = InventoryAPI.sync
  end

  private

  def exponential_backoff(current_retry)
    2 ** current_retry # 2s, 4s, 8s, 16s, 32s
  end
end
```

### Proc or Lambda

Pass a proc for inline delay calculations:

```ruby
class PollJobStatus < CMDx::Task
  # Proc
  settings retries: 10, retry_jitter: proc { |retry_count| [retry_count * 0.5, 5.0].min }

  # Lambda
  settings retries: 10, retry_jitter: ->(retry_count) { [retry_count * 0.5, 5.0].min }

  def work
    # Delays: 0.5s, 1.0s, 1.5s, 2.0s, 2.5s, 3.0s, 3.5s, 4.0s, 4.5s, 5.0s (capped)
    context.status = JobAPI.check_status(context.job_id)
  end
end
```

### Class or Module

Implement reusable delay logic in dedicated modules and classes:

```ruby
class ExponentialBackoff
  def call(task, retry_count)
    base_delay = task.context.base_delay || 1.0
    [base_delay * (2 ** retry_count), 60.0].min
  end
end

class FetchUserProfile < CMDx::Task
  # Class or Module
  settings retries: 4, retry_jitter: ExponentialBackoff

  # Instance
  settings retries: 4, retry_jitter: ExponentialBackoff.new

  def work
    # Your logic here...
  end
end
```
