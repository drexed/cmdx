# Stores

Background jobs retry. Webhooks arrive twice. Two workers pick up the same slice of work. You need a **small, shared key/value layer** — not your primary database — for idempotency tokens, rate-limit counters, circuit-breaker state, and (eventually) workflow checkpoints.

`CMDx::Stores` is that layer: `get`, `set`, `incr`, `decr`, and `del`, with optional TTL and Redis-style conditional writes (`nx` / `xx`). Call the module methods directly, or swap the backend on `CMDx.configuration.store`.

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

| Setting | Default              | In plain English             |
| ------- | -------------------- | ---------------------------- |
| `store` | `Stores::Memory.new` | Backend for `CMDx::Stores.*` |

`CMDx.reset_configuration!` (common in specs) restores a fresh in-memory store along with the rest of global config.

See also: [Configuration – Store](https://drexed.github.io/cmdx/configuration/#store).

## Module API

All methods delegate to `CMDx.configuration.store`. Keys are coerced with `to_s`; empty keys raise `ArgumentError`.

### `get(key)`

Returns the stored **string**, or `nil` when the key is missing or expired.

```ruby
CMDx::Stores.get(:session)
```

### `set(key, value, ttl: nil, nx: false, xx: false)`

Writes `value` (coerced with `to_s`). Returns whether the write happened.

| Option     | Meaning                                                    |
| ---------- | ---------------------------------------------------------- |
| `ttl:`     | Positive integer seconds until expiry (`nil` = no expiry)  |
| `nx: true` | Set only if the key is **absent** (compare Redis `SET NX`) |
| `xx: true` | Set only if the key is **present**                         |

`nx` and `xx` cannot both be `true`.

```ruby
# Claim an idempotency slot for five minutes
claimed = CMDx::Stores.set("idem:pay_123", "processing", nx: true, ttl: 300)

# Mark complete only if we still own the key
CMDx::Stores.set("idem:pay_123", "done", xx: true, ttl: 300)
```

### `incr(key, ttl: nil)`

Atomically increments a counter (starts at `1`). Returns the **integer** count after increment.

When `ttl:` is set, built-in adapters **refresh** expiry on every increment — a sliding window for rate limits and [circuit breaker](https://drexed.github.io/cmdx/circuit_breaker/index.md) failure counts.

```ruby
hits = CMDx::Stores.incr("rl:user:42", ttl: 60)
```

### `decr(key, ttl: nil)`

Atomically decrements a counter (missing keys behave as `0`). Returns the **integer** count after decrement. Built-in adapters remove the key when the count reaches zero.

`ttl:` is accepted for API symmetry with `incr`; built-in adapters do not refresh expiry on decrement.

```ruby
CMDx::Stores.decr("rl:user:42")
```

### `remaining_ttl(key)`

Returns seconds until expiry when the configured backend implements `ttl` (`Stores::Memory`, `Stores::Redis`); otherwise `nil`. Used for `metadata[:retry_after]` on open circuits.

### `del(key)`

Removes the key. Returns `1` if a key was removed, `0` otherwise.

```ruby
CMDx::Stores.del("idem:pay_123")
```

### `del_if(key, expected)`

Removes the key only when the stored value equals `expected` (string comparison after `to_s`). Returns whether a key was removed. Built-in adapters implement this atomically (Redis via `EVAL`). Used by `lock_with` so a late releaser cannot delete a newer holder's lease.

## Adapters

### `CMDx::Stores::Memory`

Thread-safe, process-local hash with monotonic-clock TTL. Used by default and in specs unless you assign another backend.

```ruby
memory = CMDx::Stores::Memory.new
memory.set(:k, "v", ttl: 30)
```

Note

Each Puma worker, Sidekiq process, and console session has its **own** memory store. Do not rely on it for cross-worker coordination.

### `CMDx::Stores::Redis`

Wraps any client that quacks like `redis-rb`: `get`, `set` (with `ex:`, `nx:`, `xx:`), `incr`, `decr`, `expire`, `ttl`, `del`, and `eval` (for `del_if`). CMDx does **not** add a Redis gem dependency — you pass the connection your app already uses.

Every key is prefixed with `namespace` (default `"cmdx:store"`) so CMDx data stays namespaced in a shared Redis instance.

```ruby
CMDx::Stores::Redis.new(redis: Redis.current, namespace: "myapp:cmdx")
# writes "myapp:cmdx:token" in Redis
```

## Custom backends

Any object that implements the core methods with the same signatures can be assigned to `config.store`. Add `del_if` when you use `lock_with`, and `ttl` when you need `remaining_ttl` (circuit breaker `retry_after`, lock `metadata[:retry_after]`). Use custom backends for Memcached, DynamoDB, observability wrappers, or an in-test spy.

Walkthrough with a recording store for specs and an instrumented Redis wrapper: [Store Wrappers](https://drexed.github.io/cmdx/cookbook/store_wrappers/index.md).

```ruby
class NullStore
  def get(_key) = nil
  def set(_key, _value, ttl: nil, nx: false, xx: false) = true
  def incr(_key, ttl: nil) = 1
  def decr(_key, ttl: nil) = 0
  def ttl(_key) = nil
  def del(_key) = 0
  def del_if(_key, _expected) = false
end

CMDx.configure { |c| c.store = NullStore.new }
```

## Testing

Specs call `CMDx.reset_configuration!` in `spec_helper`, so `CMDx::Stores` starts on a clean in-memory backend every example. To assert against an isolated instance without touching global config:

```ruby
store = CMDx::Stores::Memory.new
CMDx.configuration.store = store

store.set(:token, "abc")
expect(CMDx::Stores.get(:token)).to eq("abc")
```

For integration tests against Redis semantics, assign `CMDx::Stores::Redis.new(redis: …)` in a `before` block and point `redis` at `MockRedis` or a dedicated test Redis URL.
