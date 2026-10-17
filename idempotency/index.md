# Idempotency

Background jobs retry. Webhooks arrive twice. Two workers pick up the same slice of work. For operations that must not run twice (charging a card, sending an email), you need a **stable key** from the payload and a shared claim so the second caller stops before `work` runs.

`idempotent_by` wires that pattern into {Stores} using `set(..., nx: true)` to claim a slot and `xx: true` to mark completion — without registering middleware yourself.

Important nuance: the claim runs **after inputs are resolved** and **wraps the whole `retry_on` loop**, not each attempt. One successful run marks the slot `completed`; a raised error deletes the claim so retries can call `work` again. See [Retries](https://drexed.github.io/cmdx/retries/index.md) for what retries do *not* re-run (inputs, most callbacks).

## Basic usage

Resolve a key from context (after coercion) or from a block/callable:

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

| Option            | Default       | Plain-English meaning                                                                        |
| ----------------- | ------------- | -------------------------------------------------------------------------------------------- |
| `ttl:`            | `300`         | Seconds until the store entry expires (re-claims allowed after expiry)                       |
| `namespace:`      | `"cmdx:idem"` | First segment of the store key (see [Store keys](#store-keys))                               |
| `on_duplicate:`   | `:skip`       | `:skip` → skipped result; `:fail` → failed result (both set `metadata[:code] == :duplicate`) |
| `if:` / `unless:` | `nil`         | Gates on the task before claiming (same `Util.satisfied?` shape as other features)           |

### Key resolvers

| Form                          | How the segment is resolved                                   |
| ----------------------------- | ------------------------------------------------------------- |
| `Symbol` (e.g. `:payment_id`) | `context[payment_id]` after inputs run                        |
| `String`                      | Used literally as the segment                                 |
| Block / `Proc`                | `instance_exec` on the task — `self` is the task; optional \` |
| Other `#call`                 | `call(task)` — e.g. a small resolver object                   |

```ruby
idempotent_by { "#{user_id}:#{context.idempotency_key}" }

idempotent_by ->(task) { "#{task.context.user_id}:#{task.context.idempotency_key}" }
```

When the resolved segment is blank (`nil` or empty string), idempotency is **not** applied and `work` runs normally (no store write).

## Store keys

Keys are built with `CMDx::StoreKey.compose(namespace, task.class.name, segment)` — colon-separated, each segment coerced with the same rules as `CMDx::Stores.key!` (empty segments raise `ArgumentError`).

Example: `cmdx:idem:ChargeCustomer:pay_123`

While work is in flight the value is `"processing"`; after a successful run it becomes `"completed"`. Duplicates read the current value for the skip/fail message (`state=processing` or `state=completed`).

## Interaction with `retry_on`

```text
resolve_inputs! → idempotent claim → retry loop { work } → verify_outputs!
```

If `work` raises `StandardError`, the claim is **deleted** before the exception propagates into `retry_on`. When retries eventually succeed, the slot is marked `completed`. A later invocation with the same key short-circuits without running `work`.

Configure `CMDx.configuration.store` with a shared backend (`Stores::Redis`) in production — the in-memory default is per-process only. See [Stores](https://drexed.github.io/cmdx/stores/index.md).

TTL and crashes

If a worker dies after claiming but before success or cleanup, the key expires after `ttl:` and another caller may run `work` again. Tune `ttl:` for your worst-case runtime (and deploy pauses), not just HTTP timeouts.

## Inheritance

Subclasses inherit the parent's idempotency configuration. Calling `idempotent_by` again **replaces** the key resolver when you pass a new one and **merges** options — including option-only updates such as `idempotent_by ttl: 600` (same layering idea as `retry_on`, but the key resolver is singular, not a list).

```ruby
class ApplicationTask < CMDx::Task
  idempotent_by :request_id, ttl: 600
end

class ChargeCustomer < ApplicationTask
  idempotent_by :payment_id # resolver → payment_id, ttl stays 600
end
```

## Skip vs fail on duplicates

`:skip` fits when the second call means "already handled" (idempotent no-op, HTTP 2xx). `:fail` fits when callers need an explicit rejection (for example HTTP 409).

Both attach `metadata[:code] == :duplicate` and `metadata[:idempotency_key]` with the full store key.

Signals

Duplicates invoke `skip!` or `fail!` inside the `catch` around `work`, so control does not return to your resolver — you get a `Result` with `skipped?` or `failed?` under `execute`, or a fault under `execute!`.
