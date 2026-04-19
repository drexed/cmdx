# Basics - Context

`Context` is the shared data bag passed through a task's execution. It holds inputs, intermediate values, and anything the task writes back for downstream consumers.

## Assigning Data

The hash (or Context / Task / Result) handed to `execute` is normalized into a `Context`. String keys are symbolized; nested values are not.

```ruby
CalculateShipping.execute(weight: 2.5, destination: "CA")
```

!!! note

    `Context.build` passes an existing un-frozen `Context` through unchanged, unwraps anything that responds to `#context` (Task, Result), and wraps hash-likes in a fresh `Context`.

## Accessing Data

Access context data using method notation, hash keys, or safe accessors. `ctx` is a shorthand alias for `context` on task instances.

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Method style access (preferred)
    weight = context.weight
    destination = ctx.destination

    # Predicate style — truthy check, never raises on missing keys
    context.weight?            #=> true
    context.missing_field?     #=> false

    # Hash style access
    service_type = context[:service_type]
    options = context["options"]

    # Safe access with defaults
    rush_delivery = context.fetch(:rush_delivery, false)
    carrier = context.dig(:options, :carrier)

    # Fetch or set a default (returns existing value, or stores and returns the default)
    context.retrieve(:attempt_count, 0)
    context.retrieve(:correlation_id) { SecureRandom.uuid }

    # Inspection helpers
    context.key?(:weight)      #=> true
    context.keys               #=> [:weight, :destination, ...]
    context.values             #=> [2.5, "CA", ...]
    context.size               #=> 2
    context.empty?             #=> false
  end
end
```

!!! note

    Method-style access returns `nil` for unknown keys rather than raising. `Context` includes `Enumerable`, yielding `[key, value]` pairs through `each`; `each_key` and `each_value` iterate one side.

## Modifying Context

Mutate freely inside `work` — the root task's context is frozen only after Runtime teardown:

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Direct assignment
    context.carrier = Carrier.find_by(code: context.carrier_code)
    context.calculated_at = Time.now

    # Hash-style assignment
    context[:status] = "calculating"
    context["tracking_number"] = "SHIP#{SecureRandom.hex(6)}"

    # Conditional assignment
    context.insurance_included ||= false

    # Batch updates (mutates in place; returns self)
    context.merge(
      status: "completed",
      shipping_cost: calculate_cost,
      estimated_delivery: Time.now + 3.days
    )

    # Remove a key
    context.delete(:credit_card_token)

    # Clear all data
    context.clear
  end
end
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

!!! warning "Important"

    Passing a live `Context`, `Task`, or `Result` shares the context by reference — writes in the callee are visible to the caller. Use `context.deep_dup` when you need an isolated snapshot.

    `context.to_h` exposes the backing hash by reference. `Context.build(context.to_h)` rebuilds a fresh top-level table (symbolized keys) but nested mutable values are still shared — use `deep_dup` for full isolation.
