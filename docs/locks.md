# Locks

Two workers. Same `account_id`. Same nightly reconcile job. You want **one** of them in the room at a time — but you **do** want the job to run again tomorrow.

`lock_with` grabs a short **lease** in [Stores](stores.md) (`set(..., nx: true)`). Only one invocation holds the key while it runs. When that run finishes — success, skip, fail, or error — the lease is released. Unlike [Idempotency](idempotency.md), the next run with the same key is welcome once the lock is gone.

!!! tip "Locks vs idempotency"

    **Locks** keep concurrent workers from stepping on each other. **Idempotency** stops duplicate side effects when a message is redelivered. Need single-flight *and* at-most-once? Use both — see [Interaction with `idempotent_by`](#interaction-with-idempotent_by).

## Basic usage

```ruby
class ReconcileAccount < CMDx::Task
  lock_with :account_id, ttl: 600, wait: 30

  required :account_id, coerce: :string

  def work
    # ...
  end
end
```

| Option | Default | Plain-English meaning |
|--------|---------|----------------------|
| `ttl:` | `300` | How long the lease survives if the holder never releases it (crash safety). |
| `wait:` | `0` | Max seconds to wait for someone else to finish. `0`, `nil`, or `false` → try once, no waiting. |
| `namespace:` | `"cmdx:lock"` | First piece of the store key (see [Store keys](#store-keys)). |
| `on_busy:` | `:fail` | Still locked after `wait:` — `:fail` → failed result; `:skip` → skipped result (`metadata[:code] == :busy`, plus `lock_key`, and optional `holder` / `retry_after` when the backend exposes them). |
| `if:` / `unless:` | `nil` | Turn locking on or off for this run (same `Util.satisfied?` rules as other features). |

### Key resolvers

Same shapes as `idempotent_by` — pick what reads best:

| Form | How the segment is resolved |
|------|-----------------------------|
| `Symbol` (e.g. `:account_id`) | `context[account_id]` after inputs run |
| `String` | Used literally as the segment |
| Block / `Proc` | `instance_exec` on the task — `self` is the task; optional `|task|` arg matches callbacks |
| Other `#call` | `call(task)` — e.g. a small resolver object |

```ruby
lock_with { "tenant:#{tenant_id}:account:#{account_id}" }

lock_with ->(task) { "#{task.context.tenant_id}:#{task.context.account_id}" }
```

If the resolved segment is blank (`nil` or empty string), locking **steps aside** — `work` runs every time and nothing is written to the store.

## Store keys

Keys are built with `CMDx::StoreKey.compose(namespace, task.class.name, segment)` — for example `cmdx:lock:ReconcileAccount:acct_42`.

While the lease is held, the value is the holding run's task `tid` (same id as `result.tid`). On release, the key is deleted only if that token still matches — so a slow worker cannot wipe a **new** holder's lease after `ttl` expired and someone else moved in.

## Lease lifetime and `ttl`

The lease is taken **once** per task run and held until that invocation leaves the wrapped block: idempotency (if any), the full `retry_on` loop, and output verification. `ttl` is not a per-`work` timer — it is **crash insurance** for how long the key sticks around if the process never calls release.

Size `ttl:` for worst-case **hold** time:

- longest `work`
- plus all `retry_on` sleeps
- plus output verification
- plus a little headroom

If real hold time can beat `ttl`, another worker may grab the lock while the first is still running. Fix it by raising `ttl`, tightening retries, or splitting the work.

!!! warning "TTL and crashes"

    If a worker dies while holding the lease, the key sits in the store until `ttl:` expires. Until then, other workers see **busy** (or wait, if you set `wait:`). Plan `ttl` for worst-case runtime — not just your HTTP timeout.

## Runtime order

Think of one outer envelope around the whole attempt:

```text
resolve_inputs! → circuit_breaker → lock_with → idempotent_by → retry loop { work } → verify_outputs!
```

The lock wraps the idempotency claim and the entire `retry_on` loop. One holder runs every retry attempt before releasing.

## Interaction with `idempotent_by`

With both enabled, a second worker usually **waits** on the lock. When the first run **completes**, that worker acquires the lock, hits idempotency, and **skips** as a duplicate instead of running `work` again.

| You want… | Use… |
|-----------|------|
| Overlap is the problem; repeat runs later are fine | Lock alone |
| Duplicates must never enter `work` again | Idempotency alone |
| Single-flight **and** at-most-once side effects | Both |

## Skip vs fail when busy

`:skip` is for “someone else has this — treat as a no-op” (for example HTTP 202 or “already in progress”). `:fail` is for “no, you may not run right now” (for example HTTP 409).

Both set `metadata[:code] == :busy` and `metadata[:lock_key]` to the full store key. When the backend supports it, you also get `holder` (who has the lease) and `retry_after` (seconds until the key may expire).

## Telemetry

When locking is active for a run (enabled, gates pass, segment non-blank), CMDx emits [telemetry](configuration.md#telemetry) only if someone subscribed — unused events cost nothing.

| Event | When | Extra `event.payload` keys |
|-------|------|----------------------------|
| `:lock_acquired` | Lease taken, right before idempotency / retries / `work` | `lock_key` |
| `:lock_busy` | Lease not acquired within `wait:` | `code: :busy`, `lock_key`, `on_busy:`; optional `holder`, `retry_after` |

Each event also carries the usual `Telemetry::Event` fields (`cid`, `xid`, `tid`, `task`, `timestamp`, …).

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:lock_busy, ->(event) {
    StatsD.increment("cmdx.lock.busy", tags: ["task:#{event.task}"])
  })

  config.telemetry.subscribe(:lock_acquired, ->(event) {
    Rails.logger.info("[cmdx] lock #{event.payload[:lock_key]} held by #{event.tid}")
  })
end
```

`:lock_busy` fires **before** `skip!` / `fail!`, so you can metric contention even when the final result is skipped.

## Inheritance

Subclasses inherit the parent's lock. `lock_with` with no arguments returns the current config. A new key resolver **replaces** the old one; option-only calls **merge**. `lock_with false` on a subclass turns locking off.

```ruby
class ApplicationTask < CMDx::Task
  lock_with :tenant_id, ttl: 600
end

class ReconcileAccount < ApplicationTask
  lock_with :account_id # resolver → account_id, ttl stays 600
end

class PreviewReconcile < ApplicationTask
  lock_with false
end
```

Use a shared store in production (`Stores::Redis` on `CMDx.configuration.store`). The in-memory default only coordinates inside one process. See [Stores](stores.md).
