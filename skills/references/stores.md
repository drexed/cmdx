# Stores Reference

Docs: [docs/stores.md](../../docs/stores.md).

`CMDx::Stores` is a module facade over `CMDx.configuration.store`. Backends speak **strings** only — locks, idempotency tokens, and circuit state are opaque key/value pairs with optional TTL.

## Configuration

```ruby
CMDx.configure do |config|
  config.store = CMDx::Stores::Memory.new # default

  # Production (Redis-compatible client)
  config.store = CMDx::Stores::Redis.new(
    redis: Redis.new(url: ENV["REDIS_URL"]),
    namespace: "myapp:cmdx:"
  )
end
```

`CMDx.reset_configuration!` restores `Stores::Memory` in tests (`spec_helper` runs it every example).

## Module API

| Method | Purpose |
|--------|---------|
| `get(key)` | Read string value or `nil` |
| `set(key, value, ttl:, nx:, xx:)` | Write; `nx`/`xx` for compare-and-set semantics |
| `incr(key, ttl:)` / `decr(key, ttl:)` | Numeric counters (circuit failure counts) |
| `del(key)` | Delete key |
| `del_if(key, expected)` | Delete when value matches (lock release); raises `NotImplementedError` on backends without support |

Keys are normalized to strings by adapters. Use namespaced segments in task DSL (`:namespace` option) to avoid collisions.

## Task DSL

Declared on `CMDx::Task` subclasses; inherit and merge like `retry_on`. Pass `false` on a subclass to disable.

### `lock_with`

Distributed lease so only one worker runs the same logical key.

```ruby
lock_with :resource_id, ttl: 30, wait: 0.5, on_busy: :skip # or :fail
lock_with false # disable on subclass
```

Options: `:ttl`, `:namespace`, `:wait` (poll interval), `:on_busy` (`:fail` / `:skip`), `:if` / `:unless` gates `(task)`.

Telemetry: `:lock_acquired`, `:lock_busy`.

### `idempotent_by`

Claim-before-`work`; duplicates short-circuit without running `work`. Claim released on failure so `retry_on` can retry.

```ruby
idempotent_by :idempotency_key, ttl: 86_400, on_duplicate: :skip
idempotent_by ->(task) { "#{task.class.name}:#{task.context.invoice_id}" }
```

Telemetry: `:idempotency_claimed`, `:idempotency_completed`, `:idempotency_duplicate`.

### `circuit_breaker`

Shared failure counter and open flag in the store.

```ruby
circuit_breaker :class, threshold: 5, cool_off: 60, window: 300, on_open: :fail
circuit_breaker :tenant_id, on: [StandardError]
```

Telemetry: `:circuit_open`, `:circuit_tripped`, `:circuit_reset`.

## Runtime ordering

Inside `perform_work`, after inputs resolve:

`circuit_breaker` → `lock_with` → `idempotent_by` → `retry_on { work }` → output verification.

Output checks run while the lock lease and idempotency claim are still held.

## Testing

- Unit specs: `spec/cmdx/lock_spec.rb`, `idempotency_spec.rb`, `circuit_breaker_spec.rb`.
- Integration: `spec/integration/tasks/locks_spec.rb`, `idempotency_spec.rb`, `circuit_breaker_spec.rb`.
- Redis adapter: `CMDx::Testing::FakeRedis` in `spec/cmdx/stores/redis_spec.rb` (no real Redis process).
- Assert keys via `CMDx::Stores.get` using the same key shape the feature documents.
