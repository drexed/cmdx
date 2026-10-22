# Rate limit

Someone keeps hitting “forgot password.” Same email, fifty times in a minute. Your mailer is fine — your abuse budget is not.

**Rate limiting** is the turnstile at the front door: it counts how many times a task may **start** in a time window — per user, per IP, or for the whole app. Cheap to call, expensive to abuse? This is the knob.

`rate_limit` tracks those **starts** in [Stores](stores.md). It runs **once per `execute`** — retries inside `retry_on` do **not** eat extra quota. When the turnstile is full, `work` never runs.

!!! tip "Rate limits vs circuit breakers"

    **Rate limits** count **invocations** — “this caller has had enough tries.” **Circuit breakers** count **failures** — “this dependency is sick, stop hammering it.” Password resets and OTP sends usually want a rate limit; flaky inventory APIs usually want a breaker. Need both? Use both — see [Runtime order](#runtime-order).

## Basic usage

```ruby
class SendPasswordReset < CMDx::Task
  rate_limit :email, max: 5, per: 60

  required :email, coerce: :string

  def work
    Mailer.password_reset(email).deliver_later
  end
end

5.times { SendPasswordReset.execute(email: "user@example.com") }   # success
result = SendPasswordReset.execute(email: "user@example.com")
result.failed?                # => true
result.metadata[:code]        # => :rate_limited
result.metadata[:retry_after] # => seconds (when the backend exposes TTL)
```

| Option | Default | Plain-English meaning |
|--------|---------|----------------------|
| `max:` | *(required)* | How many runs you allow in the window (or bucket capacity for `:leaky_bucket`) |
| `per:` | *(required)* | Window length in seconds (`:fixed_window`) or seconds to “leak” one unit (`:leaky_bucket`) |
| `limiter:` | `:fixed_window` | Built-in or registered strategy — see [Limiters](#limiters) |
| `cost:` | `1` | How many units one admitted run costs — **only** `:leaky_bucket` reads this; `:fixed_window` always counts one start per `execute` |
| `namespace:` | `"cmdx:rl"` | First piece of store keys |
| `on_limit:` | `:fail` | `:fail` → failed result; `:skip` → skipped result (`metadata[:code] == :rate_limited`) |
| `if:` / `unless:` | `nil` | Turn rate limiting on or off for this run |

Pass `rate_limit false` on a subclass to turn off an inherited limit.

Want **one counter for the whole task type**? Use `rate_limit :class, …` or omit the key and pass only `max:` / `per:` — same bucket either way.

### Key resolvers

Pick **who shares one counter**. Same shapes as [Idempotency key resolvers](idempotency.md#key-resolvers) and [Circuit breaker scoping](circuit_breaker.md#scoping-the-breaker):

| Form | How the segment is resolved |
|------|-----------------------------|
| `:class` | No extra segment — one bucket per task class (`namespace:TaskName`) |
| `Symbol` (e.g. `:email`) | `context[email]` after inputs run |
| `String` | Used literally as the segment |
| Block / `Proc` | `instance_exec` on the task — `self` is the task; optional `\|task\|` matches callbacks |
| Other `#call` | `call(task)` — e.g. a small resolver object |

```ruby
rate_limit :email, max: 5, per: 60          # one bucket per email address
rate_limit :class, max: 100, per: 3600      # one bucket for the whole task class
rate_limit max: 50, per: 3600               # same as :class when no key is given
```

When the resolver is not `:class` and the segment is blank (`nil` or empty string), rate limiting **steps aside** for that run — same idea as [Idempotency](idempotency.md) with a blank key. Keys are built with `CMDx::StoreKey.task_key(..., class_scoped: true)` so `:class` does not read context.

## Quota is charged at the door

Think of each allowed `execute` as swiping in once. CMDx charges that swipe **before** the circuit breaker, locks, idempotency, or `work`.

If `work` raises, calls `fail!` / `skip!`, or the run retries inside `retry_on`, CMDx does **not** refund the swipe. One outer `execute` still used at most one admission — retries do not visit the turnstile again.

Size your limits for **starts**, not “only successful finishes.”

## Store keys

Base keys use `CMDx::StoreKey.task_key(task, namespace:, resolver:, class_scoped: true)` — colon-separated segments, each coerced with `CMDx::Stores.key!` (empty segments raise `ArgumentError`).

Examples:

- `cmdx:rl:SendPasswordReset:user@example.com`
- `cmdx:rl:SendPasswordReset` (with `rate_limit :class` or options-only `max:` / `per:`)

`:fixed_window` increments the base key. `:leaky_bucket` stores `"level:last_at"` at `#{store_key}:lb` with a TTL derived from capacity and `per`.

Use a shared store in production (`Stores::Redis` on `CMDx.configuration.store`). The in-memory default only counts inside one process. See [Stores](stores.md).

## Result metadata

When the turnstile says no, `skip!` / `fail!` merge the same payload as `:rate_limit_exceeded` telemetry into `result.metadata`:

| Key | Meaning |
|-----|---------|
| `:code` | `:rate_limited` |
| `:rate_limit_key` | Full base store key |
| `:limiter` | Strategy name (`:fixed_window`, `:leaky_bucket`, or your registered symbol) |
| `:max`, `:per` | Declared limits |
| `:count` | Present for `:fixed_window` (counter after `incr`, including the denied attempt) |
| `:level` | Present for `:leaky_bucket` (projected fill when denied) |
| `:retry_after` | Seconds until retry might succeed when the backend or limiter computes it |

Admitted runs do not add rate-limit fields to the result — subscribe to `:rate_limit_admitted` if you need per-run admission metrics.

## Runtime order

After inputs resolve, CMDx checks the turnstile **before** breakers, locks, and idempotency:

```text
resolve_inputs! → rate_limit → circuit_breaker → lock_with → idempotent_by → retry loop { work } → verify_outputs!
```

Retries do not re-run the limiter. One outer execution costs at most one admission (for the configured `cost`).

## Limiters

A **limiter** is the little algorithm that answers: “Is there room for one more start?” Built-ins live in `CMDx::Limiters` — same registry idea as `CMDx::Retriers` for retry jitter.

Resolution order:

1. `limiter:` as a `Proc` → `instance_exec` on the task
2. Symbol → `task.class.limiters` when the task registered `register :limiter`, otherwise `CMDx.configuration.limiters`

Each callable gets a `CMDx::RateLimit::Quota` (the question) and must return a `CMDx::RateLimit::Admission` (yes or no, plus optional hints for messages and metadata).

| `Quota` field | Role |
|---------------|------|
| `task` | Task being admitted |
| `store_key` | Base key (append suffixes if your strategy needs more state) |
| `max`, `per`, `cost` | Declared limits |
| `limiter` | Resolved strategy spec |
| `options` | Frozen declaration hash (namespace, gates, etc.) |

| `Admission` field | Role |
|-------------------|------|
| `admitted` | `true` to run `work`, `false` to signal over limit |
| `count` | Optional counter for messages / metadata (`:fixed_window`) |
| `level` | Optional fill for messages / metadata (`:leaky_bucket`) |
| `retry_after` | Optional hint in seconds |
| `limiter` | Name recorded on telemetry and metadata |

### Built-in limiters

**Fixed window** — a simple counter with a TTL. Easy to reason about; you can get a small burst right when a window rolls over.

```ruby
rate_limit :email, max: 5, per: 60, limiter: :fixed_window
```

**Leaky bucket** — capacity refills slowly (`per` seconds per unit). Smoother traffic shape; state lives at `store_key:lb`.

```ruby
rate_limit :email, max: 10, per: 30, limiter: :leaky_bucket
```

### Custom limiters

Register globally or per task with `register :limiter`:

```ruby
CMDx.configure do |config|
  config.limiters.register(:per_tenant_strict) do |quota|
    count = CMDx::Stores.incr(quota.store_key, ttl: quota.per)
    admitted = count <= quota.max
    retry_after = admitted ? nil : CMDx::Stores.remaining_ttl(quota.store_key)

    CMDx::RateLimit::Admission.new(
      admitted:,
      count:,
      level: nil,
      retry_after:,
      limiter: :per_tenant_strict
    )
  end
end

class SendInvoice < CMDx::Task
  register :limiter, :app_only, MyApp::InvoiceLimiter

  rate_limit :account_id, max: 20, per: 3600, limiter: :app_only
end
```

Pass a `Proc` as `limiter:` and CMDx runs it with `instance_exec` on the task, passing the `Quota` as the block argument. It must return an `Admission`. Unknown limiter symbols raise `CMDx::UnknownEntryError` with registered names in the message.

## Telemetry

When rate limiting is active for a run (enabled, gates pass, key resolves), CMDx emits [telemetry](configuration.md#telemetry) only if someone subscribed — unused events cost nothing.

| Event | When | Extra `event.payload` keys |
|-------|------|----------------------------|
| `:rate_limit_admitted` | Admission succeeded, before circuit breaker / lock / work | `rate_limit_key`, `limiter`, `max`, `per`; optional `count`, `level`, `retry_after` |
| `:rate_limit_exceeded` | Admission denied | `code: :rate_limited`, `rate_limit_key`, `limiter`, `on_limit:`, `max`, `per`; optional `count`, `level`, `retry_after` |

`:rate_limit_exceeded` fires **before** `skip!` / `fail!`, matching `metadata[:code] == :rate_limited` on the result.

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:rate_limit_exceeded, ->(event) {
    StatsD.increment("cmdx.rate_limit.denied", tags: [
      "task:#{event.task}",
      "limiter:#{event.payload[:limiter]}"
    ])
  })
end
```

## Inheritance

Subclasses inherit the parent’s rate limit. `rate_limit` with no arguments returns the current config (including inherited). Pass a new key to **replace** it; pass only options to **merge** (e.g. `rate_limit per: 120` on the subclass). `rate_limit false` turns it off.

```ruby
class ApplicationTask < CMDx::Task
  rate_limit :class, max: 1000, per: 3600
end

class SendSms < ApplicationTask
  rate_limit :phone, max: 3, per: 300
end

class DryRunSms < ApplicationTask
  rate_limit false
end
```
