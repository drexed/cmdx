# Custom Store

`CMDx.configuration.store` accepts any object that implements `get`, `set`, `incr`, and `del` with the same keyword options as `CMDx::Stores`. Optional `ttl` enables `CMDx::Stores.remaining_ttl` (for example circuit breaker `retry_after` metadata). Swap the backend for tests (spy / null), wrap Redis with observability, or bridge to `Rails.cache` without forking the framework.

## Contract

| Method | Returns | Notes |
|--------|---------|--------|
| `get(key)` | `String` or `nil` | Missing and expired keys → `nil` |
| `set(key, value, ttl:, nx:, xx:)` | `Boolean` | `true` when a value was written; `nx` / `xx` follow Redis `SET` semantics |
| `incr(key, ttl:)` | `Integer` | Counter after increment; when `ttl` is set, refresh expiry on every increment (built-in adapters) |
| `del(key)` | `Integer` | `1` if a key was removed, `0` otherwise |
| `del_if(key, expected)` | `Boolean` | `true` when the key was removed because the value matched; required for `lock_with` release |
| `ttl(key)` *(optional)* | `Integer` or `nil` | Seconds until expiry; omit when unsupported |

Keys arrive as `String` or `Symbol`; coerce with `to_s`. Reject blank keys with `ArgumentError` if you want to match built-in adapters.

## Setup — recording wrapper (tests)

Delegate to `CMDx::Stores::Memory` (or any inner store) and append each call to an `operations` log. Handy when middleware should prove it claimed an idempotency key without touching Redis.

```ruby
# spec/support/cmdx_recording_store.rb
# frozen_string_literal: true

class CmdxRecordingStore

  attr_reader :operations

  def initialize(inner = CMDx::Stores::Memory.new)
    @inner = inner
    @operations = []
  end

  def get(key)
    record(:get, key)
    @inner.get(key)
  end

  def set(key, value, ttl: nil, nx: false, xx: false)
    record(:set, key, value:, ttl:, nx:, xx:)
    @inner.set(key, value, ttl:, nx:, xx:)
  end

  def incr(key, ttl: nil)
    record(:incr, key, ttl:)
    @inner.incr(key, ttl:)
  end

  def del(key)
    record(:del, key)
    @inner.del(key)
  end

  private

  def record(op, key, **extra)
    @operations << { op:, key: key.to_s, **extra }
  end

end
```

## Setup — instrumented Redis (production)

Wrap the Redis adapter so every store round-trip emits an `ActiveSupport::Notifications` event. The inner store keeps namespace prefixing and TTL behavior.

```ruby
# app/stores/cmdx_instrumented_store.rb
# frozen_string_literal: true

class CmdxInstrumentedStore

  def initialize(inner: CMDx::Stores::Redis.new(redis: Redis.current))
    @inner = inner
  end

  def get(key)
    instrument(:get, key) { @inner.get(key) }
  end

  def set(key, value, ttl: nil, nx: false, xx: false)
    instrument(:set, key, ttl:, nx:, xx:) do
      @inner.set(key, value, ttl:, nx:, xx:)
    end
  end

  def incr(key, ttl: nil)
    instrument(:incr, key, ttl:) { @inner.incr(key, ttl:) }
  end

  def del(key)
    instrument(:del, key) { @inner.del(key) }
  end

  private

  def instrument(op, key, **payload)
    ActiveSupport::Notifications.instrument(
      "cmdx.store.#{op}",
      key: key.to_s,
      **payload
    ) { yield }
  end

end
```

## Usage

Point global configuration at your adapter once at boot (or per environment file).

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  config.store = CmdxInstrumentedStore.new
end
```

In a spec, assign a recording store and assert middleware side effects:

```ruby
RSpec.describe ChargeCustomer do
  let(:store) { CmdxRecordingStore.new }

  before { CMDx.configuration.store = store }

  it "claims an idempotency key before work" do
    ChargeCustomer.execute(payment_id: "pay_1", amount_cents: 100)

    expect(store.operations).to include(hash_including(op: :set, nx: true))
  end
end
```

Application code keeps calling `CMDx::Stores` — no changes inside tasks:

```ruby
CMDx::Stores.set("feature:beta", "on", ttl: 3600)
CMDx::Stores.get("feature:beta") #=> "on"
```

## Notes

!!! tip "Compose, don't reimplement"

    Prefer wrapping `CMDx::Stores::Memory` or `CMDx::Stores::Redis` over rewriting `nx` / `incr` TTL rules. You inherit the same semantics as the [Stores](https://drexed.github.io/cmdx/stores/) guide and the built-in specs.

!!! warning "Atomicity is your job"

    Built-in adapters use a mutex (memory) or Redis primitives (shared). If you bridge to a store without `SET NX` (for example a naive `Rails.cache` read/write), duplicate idempotency claims can race under concurrency — use Redis, Memcached `add`, or DynamoDB conditional writes for production locks.

!!! note "Specs and `reset_configuration!`"

    `spec_helper` calls `CMDx.reset_configuration!` before each example, which restores a fresh in-memory store. Assign `CMDx.configuration.store = …` inside the example or a `before` block when you need a custom adapter.
