# Store Wrappers

`CMDx.configuration.store` is a plug point. Anything that implements the [Stores](../stores.md) contract (`get`, `set`, `incr`, `decr`, `del`, plus `del_if` for `lock_with` and `ttl` for `remaining_ttl`) can sit behind rate limits, idempotency keys, locks, and circuit breakers.

Swap the backend for tests, wrap Redis with metrics, or bridge to your company's cache — without forking CMDx.

## Setup — recording wrapper (tests)

Delegate to `CMDx::Stores::Memory` (or any inner store) and log every call. Great when middleware should prove it claimed an idempotency key without touching Redis.

```ruby
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

  def decr(key, ttl: nil)
    record(:decr, key, ttl:)
    @inner.decr(key, ttl:)
  end

  def ttl(key)
    record(:ttl, key)
    @inner.ttl(key)
  end

  def del(key)
    record(:del, key)
    @inner.del(key)
  end

  def del_if(key, expected)
    record(:del_if, key, expected:)
    @inner.del_if(key, expected)
  end

  private

  def record(op, key, **extra)
    @operations << { op:, key: key.to_s, **extra }
  end

end
```

## Setup — instrumented Redis (production)

Wrap the Redis adapter so each round-trip emits an `ActiveSupport::Notifications` event. Prefixing and TTL behavior stay on the inner store.

```ruby
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

  def decr(key, ttl: nil)
    instrument(:decr, key, ttl:) { @inner.decr(key, ttl:) }
  end

  def ttl(key)
    instrument(:ttl, key) { @inner.ttl(key) }
  end

  def del(key)
    instrument(:del, key) { @inner.del(key) }
  end

  def del_if(key, expected)
    instrument(:del_if, key) { @inner.del_if(key, expected) }
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

Point global configuration at your adapter once at boot (or per environment).

```ruby
CMDx.configure do |config|
  config.store = CmdxInstrumentedStore.new
end
```

In specs, assign a recording store and assert middleware side effects:

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

Tasks keep calling `CMDx::Stores` — no changes inside `work`:

```ruby
CMDx::Stores.set("feature:beta", "on", ttl: 3600)
CMDx::Stores.get("feature:beta") #=> "on"
```

## Notes

### Compose, don't reimplement

Wrap `CMDx::Stores::Memory` or `CMDx::Stores::Redis` instead of rewriting `nx` / `incr` TTL rules. You inherit the same semantics as the [Stores](../stores.md) guide and the built-in specs.

### Atomicity is your job

Built-in adapters use a mutex (memory) or Redis primitives (shared). A naive `Rails.cache` read/write bridge can race on idempotency claims. Use Redis, Memcached `add`, or conditional writes in DynamoDB when concurrency matters.

### Specs and `reset_configuration!`

`spec_helper` calls `CMDx.reset_configuration!` before each example, which restores a fresh in-memory store. Assign `CMDx.configuration.store = …` in the example or a `before` block when you need a custom adapter.
