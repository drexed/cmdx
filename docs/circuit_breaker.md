# Circuit breaker

When a downstream dependency fails repeatedly, every caller still pays for timeouts and retries. A **circuit breaker** counts failures, opens after a threshold, and rejects new work until a cool-off elapses — so a partial outage does not keep hammering the dependency.

## Basic usage

One breaker per task class (default):

```ruby
class FetchInventory < CMDx::Task
  circuit_breaker threshold: 3, cool_off: 10

  required :sku, coerce: :string

  def work
    context.inventory = InventoryClient.fetch(sku, timeout: 2)
  end
end

FetchInventory.execute(sku: "ABC-123") # raises → failure recorded
# after enough failures…
FetchInventory.execute(sku: "ABC-123") # failed: circuit open (work not run)
```

| Option | Default | Plain-English meaning |
|--------|---------|----------------------|
| `threshold:` | `5` | Failures within `window:` before the circuit opens |
| `cool_off:` | `30` | Seconds the circuit stays open |
| `window:` | `60` | TTL on the failure counter (`Stores.incr`) |
| `namespace:` | `"cmdx:cb"` | First segment of store keys |
| `on_open:` | `:fail` | `:fail` → failed result; `:skip` → skipped result (`metadata[:code] == :circuit_open`) |
| `if:` / `unless:` | `nil` | Gates on the task before checking the circuit |

Pass a key resolver to scope breakers per downstream service or tenant (same shapes as [Idempotency](idempotency.md#key-resolvers)):

```ruby
circuit_breaker :stripe_account, threshold: 3, cool_off: 30
```

Use `:class` explicitly for one breaker per task type:

```ruby
circuit_breaker :class, threshold: 5
```

## Store keys

Closed-state failure counts use `CMDx::StoreKey.compose(base, "failures")`; the open flag uses `…:open` with value `"open"` and TTL `cool_off:`.

Examples:

- `cmdx:cb:FetchInventory:failures`
- `cmdx:cb:FetchInventory:open`
- `cmdx:cb:ChargeCustomer:acct_123:failures` (with `circuit_breaker :stripe_account`)

## Interaction with `retry_on`

```text
resolve_inputs! → circuit check → idempotent claim → retry loop { work } → verify_outputs!
```

Failures are recorded when `StandardError` escapes the **retry loop** (after attempts are exhausted), not on each retry attempt. A successful run clears the failure counter. Logical failures that only use `fail!` / validation errors do not increment the breaker.

Configure `CMDx.configuration.store` with a shared backend (`Stores::Redis`) in production — the in-memory default is per-process only. See [Stores](stores.md).

## Inheritance

Subclasses inherit the parent's breaker. Calling `circuit_breaker` with no arguments returns the current (possibly inherited) configuration. Calling it again **replaces** the key when you pass a new one and **merges** options — including option-only updates such as `circuit_breaker threshold: 3` (key stays `:class` when the parent enabled the breaker that way). Pass `circuit_breaker false` on a subclass to disable.

```ruby
class ExternalApiTask < CMDx::Task
  circuit_breaker :class, threshold: 5, cool_off: 30
end

class FetchInventory < ExternalApiTask
  circuit_breaker threshold: 3 # key stays :class, threshold → 3
end

class PreviewCharge < ApplicationTask
  circuit_breaker false # no store claim; work runs every time
end
```
