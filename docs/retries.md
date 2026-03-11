# Retries

CMDx provides automatic retry functionality for tasks that encounter transient failures. This is essential for handling temporary issues like network timeouts, rate limits, or database locks without manual intervention.

## Configuration Settings

| Setting         | Type                             | Default         | Description                                |
|-----------------|----------------------------------|-----------------|--------------------------------------------|
| `retries`       | `Integer`                        | `nil` (disabled) | Maximum number of retry attempts           |
| `retry_on`      | `Class`, `Array<Class>`          | `StandardError` | Exception types that trigger a retry       |
| `retry_jitter`  | `Numeric`, `Symbol`, `Proc`, callable | `nil` (no delay) | Delay strategy between retry attempts |

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

When an exception occurs during execution, CMDx automatically retries up to the configured limit. Each retry attempt is logged at the `warn` level with retry metadata. If all retries are exhausted, the task fails with the original exception.

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

    Only exceptions matching the `retry_on` configuration trigger retries. Unmatched exceptions immediately fail the task.

## Retry Jitter

Add delays between retry attempts to avoid overwhelming external services or to implement exponential backoff strategies. The delay is calculated as `jitter * current_attempt` for numeric values and invoked with the current attempt count for callable types.

### Fixed Value

Use a numeric value to calculate linear delay (`jitter * current_attempt`):

```ruby
class ImportRecords < CMDx::Task
  settings retries: 3, retry_jitter: 0.5

  def work
    # Delays: 0.5s (attempt 1), 1.0s (attempt 2), 1.5s (attempt 3)
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

  def exponential_backoff(current_attempt)
    2 ** current_attempt # 2s, 4s, 8s, 16s, 32s
  end
end
```

### Proc or Lambda

Pass a proc for inline delay calculations:

```ruby
class PollJobStatus < CMDx::Task
  # Proc
  settings retries: 10, retry_jitter: proc { |attempt| [attempt * 0.5, 5.0].min }

  # Lambda
  settings retries: 10, retry_jitter: ->(attempt) { [attempt * 0.5, 5.0].min }

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
  def call(task, attempt)
    base_delay = task.context.base_delay || 1.0
    [base_delay * (2 ** attempt), 60.0].min
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

## Retry Behavior

Understanding how retries work internally helps avoid surprises:

- **Same task instance** — Retries reuse the same task object. Context and attributes from previous attempts persist.
- **Validation skipped** — `before_validation` callbacks and attribute validation only run on the first attempt. Retries go straight to `before_execution` and `work`.
- **Errors cleared** — `task.errors` is automatically cleared before each retry so errors from previous attempts don't carry over.
- **Retry count tracked** — `result.retries` increments before each retry attempt.
- **Warn-level logging** — Each retry is logged at `warn` with the exception reason and remaining retry count.

!!! note "Retry + Middleware Interaction"

    Retries happen inside the middleware stack. The `retry` keyword re-enters the execution block, so middlewares like `Timeout` still apply to each individual retry attempt.

## Retry Results

After execution, the result object provides methods to inspect retry behavior:

```ruby
result = FetchExternalData.execute

result.retries   # => 2 (number of retry attempts made)
result.retried?  # => true (whether any retries occurred)
```

Use these methods for logging, metrics, or conditional post-processing based on retry activity.

## Error Handling

When all retry attempts are exhausted:

- **`execute`** — The task fails gracefully. `result.failure?` returns `true` and the exception message is captured in the result. If an `exception_handler` is configured, it is invoked.
- **`execute!`** — The original exception is re-raised after the task is marked as failed.

```ruby
result = FetchExternalData.execute

if result.failure?
  Rails.logger.error("Failed after #{result.retries} retries: #{result.message}")
end
```
