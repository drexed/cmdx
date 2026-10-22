# Rate limit

Someone keeps hitting “forgot password.” Same email, fifty times in a minute. Your mailer is fine — your abuse budget is not.

**Rate limiting** is the turnstile at the front door: it counts how many times a task may **start** in a time window — per user, per IP, or for the whole app. Cheap to call, expensive to abuse? This is the knob.

`rate_limit` tracks those **admissions** in [Stores](https://drexed.github.io/cmdx/stores/index.md). It runs **once per `execute`** — retries inside `retry_on` do **not** eat extra quota. When the turnstile is full, `work` never runs.

Rate limits vs circuit breakers

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

| Option            | Default         | Plain-English meaning                                                                                                                  |
| ----------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `max:`            | *(required)*    | How many runs you allow in the window (or bucket capacity for `:leaky_bucket`)                                                         |
| `per:`            | *(required)*    | Window length in seconds (`:fixed_window`) or seconds to “leak” one unit (`:leaky_bucket`)                                             |
| `limiter:`        | `:fixed_window` | Built-in or registered strategy — see [Limiters](#limiters)                                                                            |
| `cost:`           | `1`             | How many units one admitted run costs — **only** `:leaky_bucket` reads this; `:fixed_window` always counts one admission per `execute` |
| `namespace:`      | `"cmdx:rl"`     | First piece of store keys                                                                                                              |
| `on_limit:`       | `:fail`         | `:fail` → failed result; `:skip` → skipped result (`metadata[:code] == :rate_limited`)                                                 |
| `if:` / `unless:` | `nil`           | Turn rate limiting on or off for this run                                                                                              |

Pass `rate_limit false` on a subclass to turn off an inherited limit.

### Scoping

Pick **who shares one counter** — same key shapes as [Idempotency key resolvers](https://drexed.github.io/cmdx/idempotency/#key-resolvers):

```ruby
rate_limit :email, max: 5, per: 60          # one bucket per email address
rate_limit :class, max: 100, per: 3600      # one bucket for the whole task class
```

When the resolver is not `:class` and the segment is blank (missing context value), rate limiting **steps aside** for that run — same idea as [Idempotency](https://drexed.github.io/cmdx/idempotency/index.md) with a blank key.

## Admissions are not refunded

Quota is charged when the limiter **admits** the run, before `circuit_breaker`, locks, or `work`. If `work` raises, calls `fail!` / `skip!`, or the run retries inside `retry_on`, CMDx does **not** put units back — one outer `execute` still consumed at most one admission (retries do not hit the limiter again). Plan limits for “starts,” not “successful finishes.”

## Store keys

Keys use `CMDx::StoreKey.compose(namespace, task.class.name, segment)` when a segment is present, or `namespace:TaskName` for `rate_limit :class`.

Examples:

- `cmdx:rl:SendPasswordReset:user@example.com`
- `cmdx:rl:SendPasswordReset` (with `rate_limit :class`)

`:leaky_bucket` keeps extra state at `…:lb` under the same base key.

When a run is turned away, results include `metadata[:code] == :rate_limited` and, when the backend supports TTL reads, `metadata[:retry_after]` (seconds until you might get in again).

## Runtime order

After inputs resolve, CMDx checks the turnstile **before** breakers, locks, and idempotency:

```text
resolve_inputs! → rate_limit → circuit_breaker → lock_with → idempotent_by → retry loop { work } → verify_outputs!
```

Retries do not re-run the limiter. One outer execution costs at most one admission (for the configured `cost`).

Use a shared store in production (`Stores::Redis` on `CMDx.configuration.store`). The in-memory default only counts inside one process. See [Stores](https://drexed.github.io/cmdx/stores/index.md).

## Limiters

Built-in strategies live in `CMDx::Limiters` — same registry idea as `CMDx::Retriers` for retry jitter. Each limiter gets a {RateLimit::Quota} and returns a {RateLimit::Admission}.

### Built-in limiters

**Fixed window** — simple counter + TTL. Easy to reason about; you can get a small burst right when a window rolls over.

```ruby
rate_limit :email, max: 5, per: 60, limiter: :fixed_window
```

**Leaky bucket** — capacity refills slowly (`per` seconds per unit). Smoother traffic shape; state lives at `store_key:lb`.

```ruby
rate_limit :email, max: 10, per: 30, limiter: :leaky_bucket
```

### Custom limiters via the `Limiters` registry

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

Pass a `Proc` as `limiter:` and CMDx runs it with `instance_exec` on the task. It must return an `Admission`.

## Telemetry

When rate limiting is active for a run (enabled, gates pass, key resolves), CMDx emits [telemetry](https://drexed.github.io/cmdx/configuration/#telemetry) only if someone subscribed — unused events cost nothing.

| Event                  | When                                                      | Extra `event.payload` keys                                                                                              |
| ---------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `:rate_limit_admitted` | Admission succeeded, before circuit breaker / lock / work | `rate_limit_key`, `limiter`, `max`, `per`; optional `count`, `level`, `retry_after`                                     |
| `:rate_limit_exceeded` | Admission denied                                          | `code: :rate_limited`, `rate_limit_key`, `limiter`, `on_limit:`, `max`, `per`; optional `count`, `level`, `retry_after` |

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
