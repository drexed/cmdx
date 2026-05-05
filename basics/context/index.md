# Basics - Context

`Context` is the shared data bag passed through a task's execution. It holds inputs, intermediate values, and anything the task writes back for downstream consumers.

## Assigning Data

The hash (or Context / Task / Result) handed to `execute` is normalized into a `Context`. String keys are symbolized; nested values are not.

```ruby
CalculateShipping.execute(weight: 2.5, destination: "CA")
```

Note

`Context.build` passes an existing un-frozen `Context` through unchanged, unwraps anything that responds to `#context` (Task, Result), and wraps hash-likes in a fresh `Context`.

## Accessing and Modifying

Read with method, hash, or safe accessors; mutate freely inside `work` (the root context is frozen only after Runtime teardown). `ctx` is a shorthand alias for `context`.

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
    context.deep_merge(options: { carrier: "ups" })        # recurses into Hash values
    context.delete(:credit_card_token)
    context.clear                                          # wipes every entry
  end
end
```

Note

Method-style reads return `nil` for unknown keys. `Context` includes `Enumerable` and exposes the usual `keys`/`values`/`key?`/`each`/`each_key`/`each_value`. `#merge` / `#deep_merge` mutate in place and return `self`. `#store` (aliased `[]=`) symbolizes the key. See YARD for the full surface.

## Serialization

`Context` serializes cleanly for logs, telemetry payloads, and Rails `render json:` callers:

```ruby
context.to_h      #=> { weight: 2.5, destination: "CA" }  (the backing table, not a copy)
context.as_json   #=> same as to_h (aliased for Rails/ActiveSupport callers)
context.to_json   #=> '{"weight":2.5,"destination":"CA"}'  (Symbol keys are emitted as strings)
context.to_s      #=> 'weight=2.5 destination="CA"'        (space-separated key=value.inspect)
```

## Sharing Between Tasks

Context flows through nested executions. A sub-task invoked with `execute(context)` (or `execute(task)` / `execute(result)`) reuses the same underlying `Context`, so writes compound.

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

Important

Passing a live `Context`, `Task`, or `Result` shares the context by reference — writes in the callee are visible to the caller. Use `context.deep_dup` when you need an isolated snapshot.

`context.to_h` exposes the backing hash by reference. `Context.build(context.to_h)` rebuilds a fresh top-level table (symbolized keys) but nested mutable values are still shared — use `deep_dup` for full isolation.

## Strict Mode

By default, reading an unknown key via the dynamic method reader returns `nil`. Enable strict mode to raise `NoMethodError` for unknown reads instead — useful for catching typos in larger tasks.

Strict mode can be set globally or per-task:

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

Strict mode only affects the dynamic method reader. Every other access channel keeps its lenient semantics so defaults and explicit presence checks still work:

| Access                              | Behavior in strict mode |
| ----------------------------------- | ----------------------- |
| `context.missing`                   | raises `NoMethodError`  |
| `context[:missing]`                 | returns `nil`           |
| `context.fetch(:missing, :default)` | returns `:default`      |
| `context.dig(:a, :b)`               | returns `nil`           |
| `context.missing?`                  | returns `false`         |
| `context.missing = 1`               | writes succeed          |

Note

`strict_context` is re-applied on every `Task#initialize`: each nested task flips the shared context's flag to its own `settings.strict_context` for the duration of its execution, then the next task resets it. If you need consistent strict behavior across a pipeline, set it at the base class (e.g. `ApplicationTask`) so every subtask agrees.

## Pattern Matching

`Context` supports both array and hash deconstruction (Ruby 3.0+).

```ruby
result = CalculateShipping.execute(weight: 2.5, destination: "CA", options: { carrier: "ups" })

case result.context
in { destination: "CA", weight: Float => kg } if kg > 1.0
  bulk_ship(kg)
in { options: { carrier: String => code } }
  track_with(code)
end
```

`deconstruct_keys(nil)` returns the full backing table; a key list slices it (unknown keys are omitted). `deconstruct` yields `[[key, value], ...]` pairs for find-pattern matches (`in [*, [:weight, Float], *]`).
