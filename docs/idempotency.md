# Idempotency

Same `payment_id`. The webhook fires again. Sidekiq retries because the worker died mid-flight.

For work that must happen **at most once** — charge a card, send the email, reserve inventory — you need a **stable key** from the payload and a shared “already handled” claim. The second caller should stop **before** `work` runs.

`idempotent_by` wires that up with [Stores](stores.md): claim a slot using `set(..., nx: true)`, mark success with `xx: true`, and you do not register middleware yourself. To serialize concurrent workers without blocking repeat runs later, see [Locks](locks.md).

!!! warning "Important"

    The claim runs **after** inputs are resolved and **wraps the whole `retry_on` loop**, not each retry attempt. One successful run marks the slot `completed`; a raised error deletes the claim so retries can hit `work` again. See [Retries](retries.md) for what retries do *not* re-run (inputs, most callbacks).

## Basic usage

Pick a key from context (after coercion) or build one in a block:

```ruby
class ChargeCustomer < CMDx::Task
  idempotent_by :payment_id

  required :payment_id,   coerce: :string
  required :amount_cents, coerce: :integer

  def work
    context.charge = Stripe::Charge.create(
      amount:          amount_cents,
      currency:        "usd",
      idempotency_key: payment_id
    )
  end
end

ChargeCustomer.execute(payment_id: "pay_123", amount_cents: 9_900) # success
ChargeCustomer.execute(payment_id: "pay_123", amount_cents: 9_900) # skipped: duplicate
```

| Option | Default | Plain-English meaning |
|--------|---------|----------------------|
| `ttl:` | `300` | How long the store entry lives (seconds). After it expires, a new run can claim again. |
| `namespace:` | `"cmdx:idem"` | First piece of the store key (see [Store keys](#store-keys)). |
| `on_duplicate:` | `:skip` | `:skip` → skipped result; `:fail` → failed result (both set `metadata[:code] == :duplicate`). |
| `if:` / `unless:` | `nil` | Turn idempotency on or off for this run (same `Util.satisfied?` rules as other features). |

### Key resolvers

Same idea as elsewhere in CMDx — pick the shape that reads best:

| Form | How the segment is resolved |
|------|-----------------------------|
| `Symbol` (e.g. `:payment_id`) | `context[payment_id]` after inputs run |
| `String` | Used literally as the segment |
| Block / `Proc` | `instance_exec` on the task — `self` is the task; optional `|task|` arg matches callbacks |
| Other `#call` | `call(task)` — e.g. a small resolver object |

```ruby
idempotent_by { "#{user_id}:#{context.idempotency_key}" }

idempotent_by ->(task) { "#{task.context.user_id}:#{task.context.idempotency_key}" }
```

If the resolved segment is blank (`nil` or empty string), idempotency **steps aside** — `work` runs every time and nothing is written to the store.

## Store keys

Keys are built with `CMDx::StoreKey.compose(namespace, task.class.name, segment)` — colon-separated, each segment coerced like `CMDx::Stores.key!` (empty segments raise `ArgumentError`).

Example: `cmdx:idem:ChargeCustomer:pay_123`

While work is running, the value is `"processing"`. After a successful run it becomes `"completed"`. Duplicates read that value for the message (`state=processing` or `state=completed`).

## Interaction with `retry_on`

Think of one outer envelope around the whole attempt, retries included:

```text
resolve_inputs! → idempotent claim → retry loop { work } → verify_outputs! → completed
```

If `work` raises `StandardError`, the claim is **deleted** before the exception reaches `retry_on`. The claim is also released when `work` calls `skip!` or `fail!`, or when output verification fails — so a later invocation can try again. When the wrapped block finishes cleanly, the slot is `completed` and the next call with the same key never enters `work`.

Use a shared store in production (`Stores::Redis` on `CMDx.configuration.store`). The in-memory default only sees your current process. See [Stores](stores.md).

!!! warning "TTL and crashes"

    If a worker dies after claiming but before success or cleanup, the key sticks around until `ttl:` expires — then another caller may run `work` again. Set `ttl:` for your worst-case runtime (and deploy pauses), not just HTTP timeouts.

## Inheritance

Subclasses pick up the parent’s idempotency config. `idempotent_by` with no arguments returns what you have now (including inherited settings). Pass a new key resolver to **replace** the old one; pass only options to **merge** (e.g. `idempotent_by ttl: 600` keeps the same resolver). Same layering idea as `retry_on`, except the key resolver is singular, not a list. `idempotent_by false` on a subclass turns it off.

```ruby
class ApplicationTask < CMDx::Task
  idempotent_by :request_id, ttl: 600
end

class ChargeCustomer < ApplicationTask
  idempotent_by :payment_id # resolver → payment_id, ttl stays 600
end

class PreviewCharge < ApplicationTask
  idempotent_by false # no store claim; work runs every time
end
```

## Skip vs fail on duplicates

`:skip` is for “already done — treat as success” (idempotent no-op, HTTP 2xx). `:fail` is for “no, you may not run this again” (for example HTTP 409).

Both set `metadata[:code] == :duplicate` and `metadata[:idempotency_key]` to the full store key.

!!! note "Signals"

    Duplicates call `skip!` or `fail!` inside the `catch` around `work`, so your resolver does not keep running — under `execute` you get a `Result` with `skipped?` or `failed?`; under `execute!` you get a fault.

## Telemetry

When idempotency is active for a run (enabled, gates pass, segment non-blank), CMDx emits [telemetry](configuration.md#telemetry) only if someone subscribed.

| Event | When | Extra `event.payload` keys |
|-------|------|----------------------------|
| `:idempotency_claimed` | `processing` slot claimed (`nx: true`) | `idempotency_key` |
| `:idempotency_completed` | Slot marked `completed` after the wrapped block succeeds | `idempotency_key` |
| `:idempotency_duplicate` | Key already held (`processing` or `completed`) | `code: :duplicate`, `idempotency_key`, `state` |

`:idempotency_claimed` and `:idempotency_completed` bracket a successful run (claim → work, retries, and output verification → completed). Failed runs delete the claim and do **not** emit `:idempotency_completed`.

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:idempotency_duplicate, ->(event) {
    StatsD.increment("cmdx.idempotency.duplicate", tags: [
      "task:#{event.task}",
      "state:#{event.payload[:state]}"
    ])
  })
end
```

`:idempotency_duplicate` fires **before** `skip!` / `fail!`, matching the metadata on the final `Result`.
