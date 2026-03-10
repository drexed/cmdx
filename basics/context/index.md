# Basics - Context

Context is your data container for inputs, intermediate values, and outputs. It makes sharing data between tasks effortless.

## Building Context

`Context.build` intelligently handles different input types:

```ruby
# From a hash
Context.build(email: "user@example.com")

# From an existing Context (reuses if not frozen)
Context.build(existing_context)

# From a Result or Task (extracts its context)
Context.build(some_result)  # equivalent to some_result.context

# From nil (creates empty context)
Context.build(nil)
```

Important

`Context.build` raises `ArgumentError` if the argument doesn't respond to `to_h` or `to_hash`.

## Assigning Data

Context automatically captures all task inputs, normalizing keys to symbols:

```ruby
# Direct execution
CalculateShipping.execute(weight: 2.5, destination: "CA")

# Instance creation
CalculateShipping.new(weight: 2.5, "destination" => "CA")
```

Important

String keys convert to symbols automatically. Prefer symbols for consistency.

## Accessing Data

Access context data using method notation, hash keys, or safe accessors:

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Method style access (preferred)
    weight = context.weight
    destination = context.destination

    # Hash style access
    service_type = context[:service_type]
    options = context["options"]

    # Safe access with defaults
    rush_delivery = context.fetch(:rush_delivery, false)
    carrier = context.dig(:options, :carrier)

    # Fetch or set a default (returns existing value, or stores and returns the default)
    context.fetch_or_store(:attempt_count, 0)

    # Check key existence
    context.key?(:weight)  #=> true

    # Iteration
    context.each { |key, value| logger.debug("#{key}: #{value}") }
    keys = context.map { |key, _| key }

    # Shorter alias
    cost = ctx.weight * ctx.rate_per_pound  # ctx aliases context
  end
end
```

Important

Undefined attributes return `nil` instead of raising errors—perfect for optional data.

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Direct assignment
    context.carrier = Carrier.find_by(code: context.carrier_code)
    context.package = Package.new(weight: context.weight)
    context.calculated_at = Time.now

    # Hash-style assignment
    context[:status] = "calculating"
    context["tracking_number"] = "SHIP#{SecureRandom.hex(6)}"

    # Conditional assignment
    context.insurance_included ||= false

    # Batch updates
    context.merge!(
      status: "completed",
      shipping_cost: calculate_cost,
      estimated_delivery: Time.now + 3.days
    )

    # Remove sensitive data
    context.delete!(:credit_card_token)

    # Clear all data
    context.clear!
  end

  private

  def calculate_cost
    base_rate = context.weight * context.rate_per_pound
    base_rate + (base_rate * context.tax_percentage)
  end
end
```

Tip

Use context for both input values and intermediate results. This creates natural data flow through your task execution pipeline.

## Data Sharing

Share context across tasks for seamless data flow:

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

When passing `context`, a `Result`, or a `Task` to another task, the context is **shared by reference**—not copied. Mutations in one task are visible in the other. This enables natural data flow in pipelines but can cause surprises if you expect isolation. Use `context.to_h` to pass a snapshot instead.
