# Inputs - Validations

Ensure inputs meet requirements before execution. Validations run after coercions and transformations.

See [Global Configuration](../configuration.md#validators) for custom validator setup.

## Usage

Define validation rules on inputs to enforce data requirements:

```ruby
class ProcessSubscription < CMDx::Task
  # Required field with presence validation
  input :user_id, presence: true

  # String with length constraints
  optional :preferences, length: { min: 10, max: 500 }

  # Numeric range validation
  required :tier_level, inclusion: { in: 1..5 }

  # Format validation for email
  input :contact_email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    user_id       #=> "98765"
    preferences   #=> "Send weekly digest emails"
    tier_level    #=> 3
    contact_email #=> "user@company.com"
  end
end

ProcessSubscription.execute(
  user_id: "98765",
  preferences: "Send weekly digest emails",
  tier_level: 3,
  contact_email: "user@company.com"
)
```

## Built-in Validators

### Common Options

`:allow_nil` and `:message` cover the simple cases:

```ruby
class ProcessProduct < CMDx::Task
  input :tier_level, inclusion: { in: 1..5, allow_nil: true }

  input :title, length: { within: 5..100, message: "must be in optimal size" }
end
```

`:if` / `:unless` gate validators on Symbol, Proc, or `#call`-able objects:

```ruby
class ProcessProduct < CMDx::Task
  # Proc: instance_exec'd on task; arg = value
  optional :contact_email, format: {
    with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
    if: ->(value) { value.include?("@") }
  }

  # Symbol: invoked as task.product_sunsetted?(value)
  required :status, exclusion: { in: %w[recalled archived], unless: :product_sunsetted? }

  private

  def product_sunsetted?(value)
    context.company.out_of_business? || value == "deprecated"
  end
end
```

This list of options is available to all built-in validators:

| Option | Description |
|--------|-------------|
| `:allow_nil` | Skip validation when value is `nil` |
| `:if` | Symbol, Proc, or callable gate (see table below) — must evaluate truthy for validation to run |
| `:unless` | Symbol, Proc, or callable gate (see table below) — must evaluate falsy for validation to run |
| `:message` | Custom error message for validation failures |

| `:if` / `:unless` form | How it's invoked | Effective signature |
|------------------------|------------------|---------------------|
| `Symbol` (e.g. `:method_name`) | `task.send(method_name, value)` | `def method_name(value)` |
| `Proc` / lambda | `task.instance_exec(value, &proc)` (`self` is the task) | `->(value) { ... }` |
| `#call`-able object/class | `callable.call(task, value)` | `def call(task, value)` |

!!! note

    Short-form values are normalized before reaching any validator: a `Hash` passes through as options, an `Array` becomes `{ in: array }`, a `Regexp` becomes `{ with: regexp }`, `true` is `{}`, and `false`/`nil` skips the validator entirely.

### Absence

```ruby
class CreateUser < CMDx::Task
  input :honey_pot, absence: true
  # Or with a custom message: absence: { message: "must be empty" }
end
```

| Options | Description |
|---------|-------------|
| `true` | Ensures value is nil, empty string, empty collection, or whitespace-only |

### Exclusion

```ruby
class ProcessProduct < CMDx::Task
  input :status, exclusion: { in: %w[recalled archived] }
end
```

| Options | Description |
|---------|-------------|
| `:in` | The collection of forbidden values or range |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for discrete value exclusions |
| `:in_message` | Custom message for range-based exclusions |
| `:within_message` | Alias for :in_message option |

### Format

```ruby
class ProcessProduct < CMDx::Task
  # Shorthand: a bare Regexp is normalized to `{ with: regex }`
  input :sku, format: /\A[A-Z]{3}-[0-9]{4}\z/

  # Equivalent long form
  input :code, format: { with: /\A[A-Z]{3}-[0-9]{4}\z/ }
end
```

| Options | Description |
|---------|-------------|
| `:with` | Regex pattern that the value must match |
| `:without` | Regex pattern that the value must not match |

### Inclusion

```ruby
class ProcessProduct < CMDx::Task
  input :availability, inclusion: { in: %w[available limited] }
  # Enumerable members are matched with `===`, so Regex and Class members work too:
  input :sku_or_code, inclusion: { in: [/\A[A-Z]{3}-\d{4}\z/, Integer] }
end
```

| Options | Description |
|---------|-------------|
| `:in` | Range (`#cover?`) or Enumerable (`===` per member — Regex/Class/Range members match accordingly) |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for enumerable-member failures |
| `:in_message` | Custom message for range failures |
| `:within_message` | Alias for :in_message option |

### Length

```ruby
class CreateBlogPost < CMDx::Task
  input :title, length: { within: 5..100 }
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the length must fall within (inclusive) |
| `:not_within` | Range that the length must not fall within |
| `:in` | Alias for :within |
| `:not_in` | Alias for :not_within |
| `:min` / `:gte` | Minimum allowed length (inclusive, >=) |
| `:max` / `:lte` | Maximum allowed length (inclusive, <=) |
| `:gt` | Length must be strictly greater than value |
| `:lt` | Length must be strictly less than value |
| `:is` / `:eq` | Exact required length |
| `:is_not` / `:not_eq` | Length that is not allowed |
| `:nil_message` | Custom message when value does not respond to `#length` |

Each rule supports a matching `<rule>_message` override (e.g. `:min_message`, `:within_message`, `:gt_message`); aliases share their target's message key (e.g. `:gte_message` → `:min_message`).

### Numeric

```ruby
class CreateBlogPost < CMDx::Task
  input :word_count, numeric: { min: 100 }
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the value must fall within (inclusive) |
| `:not_within` | Range that the value must not fall within |
| `:in` | Alias for :within option |
| `:not_in` | Alias for :not_within option |
| `:min` / `:gte` | Minimum allowed value (inclusive, >=) |
| `:max` / `:lte` | Maximum allowed value (inclusive, <=) |
| `:gt` | Value must be strictly greater than bound |
| `:lt` | Value must be strictly less than bound |
| `:is` / `:eq` | Exact value that must match |
| `:is_not` / `:not_eq` | Value that must not match |
| `:nil_message` | Custom message when value is `nil` |

Each rule supports a matching `<rule>_message` override (e.g. `:min_message`, `:within_message`, `:gt_message`); aliases share their target's message key (e.g. `:gte_message` → `:min_message`).

### Presence

```ruby
class CreateBlogPost < CMDx::Task
  input :content, presence: true
  # Or with a custom message: presence: { message: "cannot be blank" }
end
```

| Options | Description |
|---------|-------------|
| `true` | Ensures value is not nil, empty collection, or whitespace-only string |

## Declarations

!!! warning "Important"

    Return `CMDx::Validators::Failure.new("message")` to mark the value invalid; any other return value (including `nil`, `true`, or `false`) is treated as success. The message is recorded on `task.errors` keyed by the input's **accessor name** (post-`:as`/`:prefix`/`:suffix`).

### Proc or Lambda

Use anonymous functions for simple validation logic:

```ruby
class SetupApplication < CMDx::Task
  # Proc
  register :validator, :api_key, proc do |value, options = {}|
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      CMDx::Validators::Failure.new(options[:message] || "invalid API key format")
    end
  end

  # Lambda
  register :validator, :api_key, ->(value, options = {}) {
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      CMDx::Validators::Failure.new(options[:message] || "invalid API key format")
    end
  }
end
```

### Class or Module

Register custom validation logic for specialized requirements:

```ruby
class ApiKeyValidator
  def self.call(value, options = {})
    return if value.match?(/\A[a-zA-Z0-9]{32}\z/)

    CMDx::Validators::Failure.new(options[:message] || "invalid API key format")
  end
end

class SetupApplication < CMDx::Task
  register :validator, :api_key, ApiKeyValidator

  input :access_key, api_key: true
end
```

### Inline `:validate` callable

For one-off validations that don't need a registered name, pass a `Symbol` (instance method), `Proc`, or any callable directly to `validate:`. Pass an array to chain several. Symbols receive `(value)`, Procs are `instance_exec`'d with `(value)` (`self` is the task), and `#call`-able objects receive `(value, task)`:

!!! warning "Arity asymmetry"

    `:if` / `:unless` callables receive `(task, value)`, but inline `:validate` callables receive `(value, task)`. The arguments are swapped — mirror the same gotcha that applies to inline `:coerce`.

```ruby
class CreateUser < CMDx::Task
  input :slug, validate: ->(v) {
    CMDx::Validators::Failure.new("must be lowercase") unless v == v.downcase
  }

  input :handle, validate: [:not_reserved, SlugReservationCheck]

  private

  def not_reserved(value)
    return if %w[admin root].exclude?(value)

    CMDx::Validators::Failure.new("is reserved")
  end
end

class SlugReservationCheck
  def self.call(value, task)
    return unless task.context.reserved_slugs.include?(value)

    CMDx::Validators::Failure.new("is reserved")
  end
end
```

## Removals

Remove unwanted validators:

!!! warning

    Each `deregister` call removes one validator. Use multiple calls for batch removals.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## `required` vs `presence: true`

These two aren't interchangeable:

| Declaration | When the caller omits the key |
|-------------|------------------------------|
| `required :email` | `email is required` — the missing-key error is added; validators don't run |
| `input :email, presence: true` | **No error.** Validators (including `presence`) are skipped when an optional key is absent |
| `required :email, presence: true` | Both: missing-key gate first; `presence:` then re-runs on the resolved value |

!!! danger "Optional + validator"

    Validators (including `presence`) do **not** run when an optional input's final resolved value is `nil` — the pipeline short-circuits after the default step. `input :email, presence: true` by itself enforces nothing when the caller omits `email`: declare it with `required :email` (or `required :email, presence: true`) whenever the caller must supply the key.

## Error Handling

Validation failures accumulate on `task.errors` and surface as a failed result with the joined sentence as `result.reason`. See [Inputs - Error Handling](definitions.md#error-handling) for the full lifecycle.
