# Stores

Background jobs retry. Webhooks arrive twice. Two workers pick up the same slice of work. You need a **small, shared key/value layer** — not your primary database — for idempotency tokens, rate-limit counters, circuit-breaker state, and (eventually) workflow checkpoints.

`CMDx::Stores` is that layer: `get`, `set`, `incr`, and `del`, with optional TTL and Redis-style conditional writes (`nx` / `xx`). Call the module methods directly, or swap the backend on `CMDx.configuration.store`.

## Configuration

The process default is an in-memory adapter — fine for tests and single-process dev, **not** shared across Sidekiq workers.

```ruby
CMDx.configure do |config|
  config.store = CMDx::Stores::Redis.new(
    redis: Redis.current,
    namespace: "cmdx:store"
  )
end
```

| Setting | Default | In plain English |
|---------|---------|------------------|
| `store` | `Stores::Memory.new` | Backend for `CMDx::Stores.*` |

`CMDx.reset_configuration!` (common in specs) restores a fresh in-memory store along with the rest of global config.

See also: [Configuration – Store](configuration.md#store).

## Module API

All methods delegate to `CMDx.configuration.store`. Keys are coerced with `to_s`; empty keys raise `ArgumentError`.

### `get(key)`

Returns the stored **string**, or `nil` when the key is missing or expired.

```ruby
CMDx::Stores.get(:session)
```

### `set(key, value, ttl: nil, nx: false, xx: false)`

Writes `value` (coerced with `to_s`). Returns whether the write happened.

| Option | Meaning |
|--------|---------|
| `ttl:` | Positive integer seconds until expiry (`nil` = no expiry) |
| `nx: true` | Set only if the key is **absent** (compare Redis `SET NX`) |
| `xx: true` | Set only if the key is **present** |

`nx` and `xx` cannot both be `true`.

```ruby
# Claim an idempotency slot for five minutes
claimed = CMDx::Stores.set("idem:pay_123", "processing", nx: true, ttl: 300)

# Mark complete only if we still own the key
CMDx::Stores.set("idem:pay_123", "done", xx: true, ttl: 300)
```

### `incr(key, ttl: nil)`

Atomically increments a counter (starts at `1`). Returns the **integer** count after increment.

When `ttl:` is set, built-in adapters **refresh** expiry on every increment — a sliding window for rate limits and [circuit breaker](circuit_breaker.md) failure counts.

```ruby
hits = CMDx::Stores.incr("rl:user:42", ttl: 60)
```

### `remaining_ttl(key)`

Returns seconds until expiry when the configured backend implements `ttl` (`Stores::Memory`, `Stores::Redis`); otherwise `nil`. Used for `metadata[:retry_after]` on open circuits.

### `del(key)`

Removes the key. Returns `1` if a key was removed, `0` otherwise.

```ruby
CMDx::Stores.del("idem:pay_123")
```

## Adapters

### `CMDx::Stores::Memory`

Thread-safe, process-local hash with monotonic-clock TTL. Used by default and in specs unless you assign another backend.

```ruby
memory = CMDx::Stores::Memory.new
memory.set(:k, "v", ttl: 30)
```

!!! note

    Each Puma worker, Sidekiq process, and console session has its **own** memory store. Do not rely on it for cross-worker coordination.

### `CMDx::Stores::Redis`

Wraps any client that quacks like `redis-rb`: `get`, `set` (with `ex:`, `nx:`, `xx:`), `incr`, `expire`, and `del`. CMDx does **not** add a Redis gem dependency — you pass the connection your app already uses.

Every key is prefixed with `namespace` (default `"cmdx:store"`) so CMDx data stays namespaced in a shared Redis instance.

```ruby
CMDx::Stores::Redis.new(redis: Redis.current, namespace: "myapp:cmdx")
# writes "myapp:cmdx:token" in Redis
```

## Custom backends

Any object that implements the four methods with the same signatures can be assigned to `config.store`. Use that for Memcached, DynamoDB, observability wrappers, or an in-test spy.

Walkthrough with a recording store for specs and an instrumented Redis wrapper: [Custom Store](https://github.com/drexed/cmdx/blob/main/examples/custom_store.md).

```ruby
class NullStore
  def get(_key) = nil
  def set(_key, _value, ttl: nil, nx: false, xx: false) = true
  def incr(_key, ttl: nil) = 1
  def del(_key) = 0
end

CMDx.configure { |c| c.store = NullStore.new }
```

## Patterns (today)

- [Idempotency](idempotency.md) — `idempotent_by` on tasks, backed by `CMDx::Stores`
- [Circuit breaker](circuit_breaker.md) — `circuit_breaker` on tasks, failure counting and open flags via `CMDx::Stores`

Other helpers (`concurrency_limit`, …) are still on the roadmap. Middleware built on `CMDx::Stores` remains appropriate when you need custom claim semantics beyond the built-in declarations:

- [Rate Limit](https://github.com/drexed/cmdx/blob/main/examples/rate_limit.md) — `incr` + TTL window
- [Custom Store](https://github.com/drexed/cmdx/blob/main/examples/custom_store.md) — wrap Memory/Redis for tests or instrumentation

Refactoring those examples to call `CMDx::Stores` instead of `Redis.current` keeps behavior the same while staying adapter-agnostic.

## Testing

Specs call `CMDx.reset_configuration!` in `spec_helper`, so `CMDx::Stores` starts on a clean in-memory backend every example. To assert against an isolated instance without touching global config:

```ruby
store = CMDx::Stores::Memory.new
CMDx.configuration.store = store

store.set(:token, "abc")
expect(CMDx::Stores.get(:token)).to eq("abc")
```

For integration tests against Redis semantics, assign `CMDx::Stores::Redis.new(redis: …)` in a `before` block and point `redis` at `MockRedis` or a dedicated test Redis URL.
