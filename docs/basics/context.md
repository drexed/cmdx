# Basics - Context

Think of **`Context`** as the shared notepad for a task run. It carries what came in (inputs), what you figured out along the way, and anything the next step might need. One bag, many readers and writers — all in one execution.

## Assigning Data

Whatever you pass to `execute` — a Hash, another `Context`, a `Task`, or a `Result` — gets normalized into a `Context`. String keys become symbols; nested values stay as-is (no deep magic).

```ruby
CalculateShipping.execute(weight: 2.5, destination: "CA")
```

!!! note

    `Context.build` is the traffic cop: an unfrozen `Context` passes through unchanged; things with `#context` (like `Task` or `Result`) unwrap; hash-likes become a new `Context`.

## Accessing and Modifying

You can read like an object, like a hash, or with safe helpers. While `work` is running, mutate away — the root context only freezes **after** teardown. Short alias: `ctx` means `context`.

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Reads
    weight        = context.weight              # method style (nil for unknown keys)
    service_type  = context[:service_type]      # hash style
    rush_delivery = context.fetch(:rush, false) # safe default
    carrier       = context.dig(:options, :carrier)
    attempt       = context.retrieve(:attempt_count, 0) # fetch-or-set
    context.weight?                             # truthy predicate
    context.empty?                              # false when any key stored
    context.size                                # number of top-level keys

    # Writes
    context.calculated_at = Time.now
    context[:status] = "calculating"                       # alias: context.store(:status, "...")
    context.insurance_included ||= false
    context.merge(shipping_cost: calculate_cost)           # top-level last-write-wins (mutates in place)
    context.deep_merge(options: { carrier: "ups" })      # recurses into Hash values
    context.delete(:credit_card_token)
    context.clear                                          # wipes every entry
  end
end
```

!!! note

    Method-style reads give `nil` for keys that don’t exist — no exception. `Context` is `Enumerable` and has the usual `keys` / `values` / `key?` / `each` friends. `#merge` and `#deep_merge` change the context **in place** and return `self`. `#store` (same as `[]=`) symbolizes the key. For every method, peek at the YARD docs.

## Serialization

Need to log it or return JSON? Context plays nice:

```ruby
context.to_h      #=> { weight: 2.5, destination: "CA" }  (the backing table, not a copy)
context.as_json   #=> same as to_h (aliased for Rails/ActiveSupport callers)
context.to_json   #=> '{"weight":2.5,"destination":"CA"}'  (Symbol keys are emitted as strings)
context.to_s      #=> 'weight=2.5 destination="CA"'        (space-separated key=value.inspect)
```

## Sharing Between Tasks

When a task calls another task with the **same** context object (or something that unwraps to it), you’re appending to the same notepad. Writes stack up — handy for pipelines.

```ruby
# During execution
class CalculateShipping < CMDx::Task
  def work
    # Validate shipping data
    validation_result = ValidateAddress.execute(context)

    # Via context
    CalculateInsurance.execute(context)

    # Via result
    NotifyShippingCalculated.execute(validation_result)

    # Context now contains accumulated data from all tasks
    context.address_validated    #=> true (from validation)
    context.insurance_calculated #=> true (from insurance)
    context.notification_sent    #=> true (from notification)
  end
end

# After execution
result = CalculateShipping.execute(destination: "New York, NY")

CreateShippingLabel.execute(result)
```

!!! warning "Important"

    Sharing a `Context`, `Task`, or `Result` means **by reference** — the callee’s writes show up for the caller. `context.to_h` is still the live backing hash; `Context.build(context.to_h)` copies the top level but nested objects might still be the same object in memory. Want a full snapshot? `context.deep_dup`.

## Strict Mode

By default, `context.unknown_method` is just `nil` — forgiving, sometimes *too* forgiving. Turn on **strict mode** and typos explode as `NoMethodError` so you catch them early.

Global or per-task:

```ruby
CMDx.configure do |config|
  config.strict_context = true
end

class CalculateShipping < CMDx::Task
  settings(strict_context: true)

  def work
    context.weight       #=> reads fine when set
    context.typoed_key   #=> raises NoMethodError: unknown context key :typoed_key (strict mode)
  end
end
```

Strict mode only changes the **dynamic method reader**. Brackets, `fetch`, `dig`, predicates, and writers behave like before:

| How you access | In strict mode |
|----------------|----------------|
| `context.missing` | Raises `NoMethodError` |
| `context[:missing]` | Still `nil` |
| `context.fetch(:missing, :default)` | Still `:default` |
| `context.dig(:a, :b)` | Still `nil` |
| `context.missing?` | Still `false` |
| `context.missing = 1` | Still works — assignment always allowed |

!!! note

    Strictness is reapplied on each `Task#initialize`. Nested tasks can flip the shared flag to **their** `settings.strict_context` while they run. For a whole app that should feel the same, set it once on a base class like `ApplicationTask`.

## Pattern Matching

Ruby 3+ can destructure `Context` like a hash or an array of pairs — nice for `case` expressions.

```ruby
result = CalculateShipping.execute(weight: 2.5, destination: "CA", options: { carrier: "ups" })

case result.context
in { destination: "CA", weight: Float => kg } if kg > 1.0
  bulk_ship(kg)
in { options: { carrier: String => code } }
  track_with(code)
end
```

`deconstruct_keys(nil)` returns the full table; pass a key list and you get a slice (unknown keys omitted). `deconstruct` yields `[[key, value], ...]` for find-style patterns like `in [*, [:weight, Float], *]`.
