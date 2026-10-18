# Circuit breaker

The inventory API is down. Every task still waits, times out, retries, and piles onto the same unhappy dependency.

A **circuit breaker** is the bouncer at the door: it counts failures, **opens** after too many in a row, and sends new work away until a cool-off passes. Callers stop paying for timeouts while the dependency is clearly struggling.

`circuit_breaker` adds that pattern to your task using [Stores](https://drexed.github.io/cmdx/stores/index.md) — one breaker config per task class by default, or scoped per tenant/service when you pass a key resolver.

## Basic usage

One breaker per task class (the default):

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

| Option            | Default         | Plain-English meaning                                                                  |
| ----------------- | --------------- | -------------------------------------------------------------------------------------- |
| `threshold:`      | `5`             | How many failures inside `window:` before the circuit opens                            |
| `cool_off:`       | `30`            | How long (seconds) the circuit stays open                                              |
| `window:`         | `60`            | Sliding window (seconds) for the failure counter                                       |
| `namespace:`      | `"cmdx:cb"`     | First piece of store keys                                                              |
| `on:`             | `StandardError` | Exception classes that count as “this dependency failed”                               |
| `on_open:`        | `:fail`         | `:fail` → failed result; `:skip` → skipped result (`metadata[:code] == :circuit_open`) |
| `if:` / `unless:` | `nil`           | Turn the breaker on or off for this run                                                |

### Scoping the breaker

Pass a key resolver when one task talks to several downstreams (or tenants). Same shapes as [Idempotency key resolvers](https://drexed.github.io/cmdx/idempotency/#key-resolvers):

```ruby
circuit_breaker :stripe_account, threshold: 3, cool_off: 30
```

Explicit “one breaker per task type”:

```ruby
circuit_breaker :class, threshold: 5
```

Count only real dependency pain — not every `StandardError` in your app:

```ruby
circuit_breaker :class, threshold: 3, on: [Stripe::APIError, Timeout::Error]
```

When the resolver is not `:class` and the segment is blank (missing context value), the breaker **steps aside** for that run — same as [Idempotency](https://drexed.github.io/cmdx/idempotency/index.md) with a blank key.

## Store keys

Failure counts (circuit **closed**) use `CMDx::StoreKey.compose(base, "failures")`. The open flag uses `…:open` with value `"open"` and TTL `cool_off:`.

Examples:

- `cmdx:cb:FetchInventory:failures`
- `cmdx:cb:FetchInventory:open`
- `cmdx:cb:ChargeCustomer:acct_123:failures` (with `circuit_breaker :stripe_account`)

When the circuit is open, results include `metadata[:circuit_breaker_key]` (the full `…:open` key) and, when the backend supports TTL reads, `metadata[:retry_after]` (seconds until the open flag expires).

### Failure window

`window:` is **sliding**, not “reset at midnight.” Each counted failure calls `Stores.incr` with `ttl: window`, and built-in adapters refresh expiry on every bump. Go `window` seconds without a new failure and the counter key disappears — the next failure starts from `1` again.

## Interaction with `retry_on`

Breakers run early; idempotency (if any) sits just inside:

```text
resolve_inputs! → circuit check → idempotent claim → retry loop { work } → verify_outputs!
```

Failures are recorded when a matching `on:` exception escapes the **retry loop** (after attempts are exhausted), not on every retry swing. A successful run clears the failure counter. Logical failures that only use `fail!` or validation errors do **not** trip the breaker.

Use a shared store in production (`Stores::Redis` on `CMDx.configuration.store`). The in-memory default only sees your current process. See [Stores](https://drexed.github.io/cmdx/stores/index.md).

## Store availability

When the store itself is flaky, CMDx picks a side — on purpose:

| Situation                              | Behavior                                                                         |
| -------------------------------------- | -------------------------------------------------------------------------------- |
| Circuit **open**                       | `work` does not run; `on_open:` applies.                                         |
| **Read** fails while checking open     | Treated as **closed** (fail-open): work runs.                                    |
| **Write** fails after a failed run     | The work exception still raises; the failure might not be counted.               |
| **Write** fails after a successful run | The failure counter might not clear; the next error may open the circuit sooner. |

## Concurrency

The breaker peeks at the open flag again right before `work`. There is no distributed lock — a task can still start moments before another process opens the circuit, and when the `:open` TTL expires many workers may call the dependency at once. Plan for that at the dependency layer if you need stricter guarantees.

## Inheritance

Subclasses inherit the parent’s breaker. `circuit_breaker` with no arguments returns the current config (including inherited). Pass a new key to **replace** it; pass only options to **merge** (e.g. `circuit_breaker threshold: 3` keeps `:class` when the parent enabled the breaker that way). `circuit_breaker false` on a subclass turns it off.

```ruby
class ExternalApiTask < CMDx::Task
  circuit_breaker :class, threshold: 5, cool_off: 30
end

class FetchInventory < ExternalApiTask
  circuit_breaker threshold: 3 # key stays :class, threshold → 3
end

class PreviewInventory < ExternalApiTask
  circuit_breaker false # no breaker; work runs every time
end
```
