# Retries

CMDx retries `work` automatically when it raises an exception that matches a class-level `retry_on` declaration. Retries are scoped to `work` itself — input resolution, output verification, and lifecycle callbacks run only once.

## Basic Usage

`retry_on` takes one or more exception classes and an options hash. With no exceptions declared (the default), no retries happen.

```ruby
class FetchExternalData < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout

  def work
    response = HTTParty.get("https://api.example.com/data")
    context.data = response.parsed_response
  end
end
```

| Option       | Default | Description                                                                                                                            |
| ------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `limit:`     | `3`     | Maximum retry attempts (total invocations = `limit + 1`); `0` disables retries entirely                                                |
| `delay:`     | `0.5`   | Base delay in seconds; `0` disables sleeping between attempts                                                                          |
| `max_delay:` | `nil`   | Upper bound clamp applied after jitter is computed                                                                                     |
| `jitter:`    | `nil`   | Strategy for spreading delays — see [Jitter](#jitter) below                                                                            |
| `if:`        | `nil`   | Gate evaluated per attempt; when falsy the exception is re-raised instead of retried — see [Conditional Retries](#conditional-retries) |
| `unless:`    | `nil`   | Inverse of `if:` — when truthy the exception is re-raised                                                                              |

```ruby
class ProcessPayment < CMDx::Task
  retry_on Stripe::RateLimitError, Net::ReadTimeout,
           limit: 5, delay: 1.0, max_delay: 30.0, jitter: :exponential

  def work
    # ...
  end
end
```

Important

Only exceptions matching `retry_on` retry. Anything else — or a matching exception after the limit is exhausted — is captured by Runtime and turned into a failed result with the exception attached as `result.cause`.

## Inheritance

`retry_on` accumulates across inheritance — subclasses extend the parent's exceptions and merge options instead of replacing them.

```ruby
class ApplicationTask < CMDx::Task
  retry_on Net::OpenTimeout, limit: 2
end

class FetchProfile < ApplicationTask
  retry_on Net::ReadTimeout, max_delay: 5.0
  # Effective: [Net::OpenTimeout, Net::ReadTimeout], limit: 2, max_delay: 5.0
end
```

## Jitter

Jitter spreads delay across attempts. Strategies receive `(attempt, delay)` where `attempt` is zero-based and `delay` is the base delay. The result is clamped to `max_delay` if set.

### Built-in Strategies

```ruby
retry_on TransientError, delay: 1.0, jitter: :exponential
# attempt 0 → 1s, attempt 1 → 2s, attempt 2 → 4s, ...

retry_on TransientError, delay: 2.0, jitter: :half_random
# delay/2 .. delay      → 1.0s .. 2.0s

retry_on TransientError, delay: 2.0, jitter: :full_random
# 0       .. delay      → 0.0s .. 2.0s

retry_on TransientError, delay: 2.0, jitter: :bounded_random
# delay   .. 2*delay    → 2.0s .. 4.0s

retry_on TransientError, delay: 1.0, jitter: :linear
# attempt 0 → 1s, attempt 1 → 2s, attempt 2 → 3s, ...

retry_on TransientError, delay: 1.0, jitter: :fibonacci
# attempt 0 → 1s, attempt 1 → 1s, attempt 2 → 2s, attempt 3 → 3s, attempt 4 → 5s, ...

retry_on TransientError, delay: 1.0, jitter: :decorrelated_jitter
# AWS-style: next sleep ∈ [delay, prev_sleep * 3], starting from prev = delay
# attempt 0 → 1.0s..3.0s, then each subsequent attempt's upper bound is 3× the
# previous sleep (clamped by :max_delay if set)
```

Note

`:decorrelated_jitter` is stateful — the previous sleep is threaded across retries inside a single `process` call. Calling `#wait` directly without passing `prev_delay` falls back to the base delay each time.

### Custom Strategies via the `Retriers` Registry

Built-in strategies live in the `CMDx::Retriers` registry, mirroring `Mergers` and `Executors`. Strategies are any callable matching `call(attempt, delay, prev_delay)` returning the next delay in seconds. Register custom strategies globally on the configuration or per-task:

```ruby
CMDx.configure do |config|
  config.retriers.register(:capped_exponential) do |attempt, delay, _prev|
    [delay * (2**attempt), 30.0].min
  end
end

class FetchExternalData < CMDx::Task
  retry_on Net::ReadTimeout, jitter: :capped_exponential

  # Or scoped to the task class only:
  register :retrier, :doubled, ->(_a, delay, _p) { delay * 2 }
end
```

Symbols not present in the registry fall through to a task instance method, so existing `jitter: :exponential_backoff` declarations keep working.

### Symbol (Instance Method)

A `Symbol` resolves to an instance method on the task. The method receives `(attempt, delay)` and must return the desired sleep duration in seconds.

```ruby
class SyncInventory < CMDx::Task
  retry_on InventoryAPI::ServerError, limit: 5, jitter: :exponential_backoff

  def work
    context.inventory = InventoryAPI.sync
  end

  private

  def exponential_backoff(attempt, delay)
    delay * (2**attempt)
  end
end
```

### Proc or Lambda

Procs and lambdas are evaluated with `instance_exec` against the task, so they have access to `context` and other instance methods.

```ruby
class PollJobStatus < CMDx::Task
  retry_on JobAPI::Pending,
           limit: 10,
           delay: 0.5,
           max_delay: 5.0,
           jitter: ->(attempt, delay) { delay * (attempt + 1) }

  def work
    context.status = JobAPI.check_status(context.job_id)
  end
end
```

### Callable (Class or Module)

Anything responding to `#call(attempt, delay)` works. The task is **not** passed in — capture state in the callable instead.

```ruby
class ExponentialBackoff
  def initialize(base: 1.0, cap: 60.0)
    @base = base
    @cap  = cap
  end

  def call(attempt, _delay)
    [@base * (2**attempt), @cap].min
  end
end

class FetchUserProfile < CMDx::Task
  retry_on Net::ReadTimeout, limit: 4, jitter: ExponentialBackoff.new(base: 0.5)

  def work
    # ...
  end
end
```

### Custom Block

When no `:jitter` option is given, you can pass a block to `retry_on` instead. It runs in the task's instance scope.

```ruby
class FetchAnalytics < CMDx::Task
  retry_on Analytics::Throttled, limit: 3, delay: 1.0 do |attempt, delay|
    delay + (attempt ** 1.5)
  end
end
```

## Conditional Retries

`:if` / `:unless` gate each retry attempt. When the gate is falsy (`if`) or truthy (`unless`), the rescued exception is re-raised instead of retried, skipping any remaining budget and the `wait` between attempts.

| Gate form       | How it's invoked                                                 | Effective signature              |
| --------------- | ---------------------------------------------------------------- | -------------------------------- |
| `Symbol`        | `task.send(sym, error, attempt)`                                 | `def sym(error, attempt)`        |
| `Proc` / lambda | `task.instance_exec(error, attempt, &gate)` (`self` is the task) | `->(error, attempt) { ... }`     |
| `#call`-able    | `gate.call(task, error, attempt)`                                | `def call(task, error, attempt)` |

```ruby
class FetchProfile < CMDx::Task
  retry_on ApiError,
           limit: 5,
           delay: 1.0,
           if: ->(error, _attempt) { error.retryable? }

  retry_on Net::ReadTimeout, if: :transient?, limit: 3

  def work
    context.profile = ApiClient.fetch(context.user_id)
  end

  private

  def transient?(error, _attempt) = !error.message.include?("permanent")
end
```

Note

The gate fires *before* `wait` sleeps. When the gate rejects, no delay elapses — the exception propagates immediately and Runtime converts it to a failed result (or raises under `execute!`).

## Behavior

- **Same task instance** — retries reuse the same task object. `context` and any side effects from previous attempts persist.
- **Only `work` repeats** — input resolution, output verification, and `before_execution` / `before_validation` callbacks run once. Retries wrap `work` only. (This is intentional — flaky input sources are not retried here; wrap the source in a `retry_on` around its own fetcher or in a middleware.)
- **Errors carry over** — `task.errors` accumulates across attempts; entries added during a previous attempt remain. Clear them at the start of `work` if you re-add per attempt, otherwise a successful retry will still finalize as failed once `signal_errors!` runs.
- **Telemetry** — Runtime emits a `:task_retried` event for each retry (`attempt:` is zero-based; the initial call is `attempt = 0` and is not emitted).
- **Inside the middleware stack** — middlewares wrap the entire lifecycle (callbacks, inputs, retries, outputs, rollback). Each retried `work` call is *inside* every middleware, so middlewares see the task once per execution, not once per attempt. Subscribe to the `:task_retried` telemetry event if you need per-attempt visibility.

## Inspecting Retries

`Result` exposes retry metadata after execution:

```ruby
result = FetchExternalData.execute

result.retries   #=> 2  (number of *retry* attempts; 0 if first attempt succeeded)
result.retried?  #=> true
```

These are also surfaced in the structured log output (`retried`, `retries`).

## When Retries Are Exhausted

Once `limit` retries are spent, the last exception is re-raised inside `work` and Runtime converts it:

- `execute` — captured by `rescue StandardError`; produces a failed result with `result.cause` set to the exception and `result.reason` set to `"[ExceptionClass] message"`.
- `execute!` — same conversion, but Runtime re-raises the original exception (not a `Fault`) after the lifecycle finalizes.

```ruby
result = FetchExternalData.execute

if result.failed?
  Rails.logger.error("Failed after #{result.retries} retries: #{result.reason}")
end
```
