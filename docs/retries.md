# Retries

Networks flake. APIs rate-limit you. Sometimes the universe just says “not yet.”

`retry_on` tells CMDx: **when `work` raises one of these exception types, wait a beat and try again** — up to a limit you control.

Important nuance: retries only rerun **`work`**. Inputs, outputs, and most lifecycle callbacks still run **once** per execution. That keeps retries predictable: you are not re-validating the world on every attempt unless you put that logic inside `work` (or another layer).

## Basic Usage

List the exception classes you care about. If you never declare `retry_on`, nothing is retried.

```ruby
class FetchExternalData < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout

  def work
    response = HTTParty.get("https://api.example.com/data")
    context.data = response.parsed_response
  end
end
```

| Option       | Default | Plain-English meaning |
|--------------|---------|----------------------|
| `limit:`     | `3`     | How many **retries** after the first try. Total runs = `limit + 1`. Set `limit: 0` to turn retries off. |
| `delay:`     | `0.5`   | Base pause in seconds between tries. `0` means “do not sleep.” |
| `max_delay:` | `nil`   | Cap the sleep so jittered waits do not grow forever. |
| `jitter:`    | `nil`   | How to **wiggle** the delay so thundering herds calm down — see [Jitter](#jitter). |
| `if:`        | `nil`   | Per-attempt gate: when falsy, stop retrying and re-raise. See [Conditional Retries](#conditional-retries). |
| `unless:`    | `nil`   | Inverse of `if:` — when truthy, re-raise instead of retrying. |

```ruby
class ProcessPayment < CMDx::Task
  retry_on Stripe::RateLimitError, Net::ReadTimeout,
           limit: 5, delay: 1.0, max_delay: 30.0, jitter: :exponential

  def work
    # ...
  end
end
```

!!! warning "Important"

    Only exceptions you listed in `retry_on` get a second chance. Everything else — or a listed exception after you run out of retries — becomes a normal failed result (with `result.cause` under `execute`), or blows up under `execute!` once the lifecycle finishes.

## Inheritance

Subclasses **add** to the parent’s retry rules; they do not wipe the slate clean. Exceptions accumulate; options merge sensibly.

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

“Jitter” is a fancy word for **random-ish spacing** so many clients do not all wake up at the exact same millisecond.

Built-in strategies receive `(attempt, delay)` where `attempt` is zero-based and `delay` is your base delay. The computed sleep is clamped by `max_delay` when you set it.

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

!!! note

    `:decorrelated_jitter` remembers the previous sleep **within one** `process` call. If something calls `#wait` without passing `prev_delay`, it falls back to the base delay — fine for normal retries, just know the state is scoped to that run.

### Custom Strategies via the `Retriers` Registry

Built-ins live in `CMDx::Retriers` (same idea as `Mergers` and `Executors`). A strategy is any callable shaped like `call(attempt, delay, prev_delay)` → seconds to sleep.

Register globally in config, or per-task with `register :retrier`:

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

If a symbol is not in the registry, CMDx falls back to an **instance method** on the task — so older `jitter: :my_custom_method` style configs keep working.

### Symbol (Instance Method)

The method receives `(attempt, delay)` and returns how long to sleep, in seconds.

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

Procs run with `instance_exec` on the task, so `context` and your helpers are right there.

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

Anything with `#call(attempt, delay)` works. The task is **not** passed in — bake config into the object.

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

No `:jitter` option? You can pass a block to `retry_on` instead. It runs as instance code on the task.

```ruby
class FetchAnalytics < CMDx::Task
  retry_on Analytics::Throttled, limit: 3, delay: 1.0 do |attempt, delay|
    delay + (attempt ** 1.5)
  end
end
```

## Conditional Retries

`:if` / `:unless` let you say “this exception **matches**, but do not retry **this time**.” When the gate says no, the exception is re-raised immediately — no more sleeps, no more attempts.

| Gate form | How it runs | Think of it as |
|-----------|-------------|----------------|
| `Symbol` | `task.send(sym, error, attempt)` | `def sym(error, attempt)` |
| `Proc` / lambda | `task.instance_exec(error, attempt, &gate)` | `->(error, attempt) { ... }` |
| `#call`-able | `gate.call(task, error, attempt)` | `def call(task, error, attempt)` |

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

!!! note

    The gate runs **before** the sleep. If it rejects a retry, you do not wait — you fail fast, and Runtime turns that into a failed result (or raises under `execute!`).

## Behavior

- **Same task object** — `context` and any ivars mutated in earlier attempts are still there. Design `work` accordingly.
- **Only `work` loops** — inputs, outputs, and `before_execution` / `before_validation` callbacks are not replayed per retry. If your *input source* is flaky, wrap that fetch in its own task with `retry_on`, or use middleware — do not expect CMDx to magically re-resolve inputs for free.
- **`task.errors` sticks around** — errors added on a failed attempt remain. Clear at the top of `work` if each attempt should start fresh; otherwise a later success might still lose at `signal_errors!`.
- **Telemetry** — each retry emits `:task_retried` (`attempt` is zero-based; the first run is attempt `0` and does **not** emit).
- **Middleware sees one execution** — middleware wraps the whole lifecycle, so it does not “re-enter” per retry. For per-attempt hooks, listen to `:task_retried`.

## Inspecting Retries

After the run, ask the `Result`:

```ruby
result = FetchExternalData.execute

result.retries   #=> 2  (number of *retry* attempts; 0 if first attempt succeeded)
result.retried?  #=> true
```

Structured logs include `retried` / `retries` too.

## When Retries Are Exhausted

After the last allowed retry, the exception surfaces like any other unhandled error from `work`:

- **`execute`** — Runtime rescues, you get `result.failed?`, `result.cause` is the exception, `result.reason` looks like `"[ExceptionClass] message"`.
- **`execute!`** — same lifecycle handling, then the **original** exception is re-raised (not wrapped as `CMDx::Fault`).

```ruby
result = FetchExternalData.execute

if result.failed?
  Rails.logger.error("Failed after #{result.retries} retries: #{result.reason}")
end
```
