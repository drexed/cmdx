# Inputs - Validations

Think of validations as the bouncer at the door: they check that each input looks right **before** your task runs its real work. They run **after** coercions and transformations, so they always see the “final” shape of the value.

Need to plug in your own validator machinery app-wide? Peek at [Global Configuration](../configuration.md#validators).

## Usage

You attach validation rules right on the input. If something fails, the task stops early and you get clear errors — no surprises halfway through `work`:

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

### Common options

Most validators understand a few shared knobs:

- **`:allow_nil`** — “Skip this check when the value is `nil`.”
- **`:message`** — Your own words when something fails.

```ruby
class ProcessProduct < CMDx::Task
  input :tier_level, inclusion: { in: 1..5, allow_nil: true }

  input :title, length: { within: 5..100, message: "must be in optimal size" }
end
```

**Conditional checks** use `:if` and `:unless`. You can hand in a `Symbol`, a `Proc`, or anything that responds to `#call`:

```ruby
class ProcessProduct < CMDx::Task
  # Proc: runs in the context of the task; argument is the current value
  optional :contact_email, format: {
    with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
    if: ->(value) { value.include?("@") }
  }

  # Symbol: calls `product_sunsetted?(value)` on the task
  required :status, exclusion: { in: %w[recalled archived], unless: :product_sunsetted? }

  private

  def product_sunsetted?(value)
    context.company.out_of_business? || value == "deprecated"
  end
end
```

These options work across the built-in validators:

| Option | What it does |
|--------|----------------|
| `:allow_nil` | Don’t validate when the value is `nil` |
| `:if` | Only run the validator when this is truthy (see below) |
| `:unless` | Only run the validator when this is falsy (see below) |
| `:message` | Custom failure message |

| `:if` / `:unless` shape | How it runs | Think of the signature as |
|-------------------------|-------------|---------------------------|
| `Symbol` (e.g. `:method_name`) | `task.send(method_name, value)` | `def method_name(value)` |
| `Proc` / lambda | `task.instance_exec(value, &proc)` — `self` is the task | `->(value) { ... }` |
| `#call`-able object | `callable.call(task, value)` | `def call(task, value)` |

!!! note

    **Shorthand shapes:** a lone `Hash` becomes options, an `Array` becomes `{ in: array }`, a `Regexp` becomes `{ with: regexp }`, `true` becomes `{}`, and `false` / `nil` turns the validator off entirely. Less typing, same behavior.

### Absence

“Please be empty.” Handy for honeypot fields and “this must not be filled in” cases.

```ruby
class CreateUser < CMDx::Task
  input :honey_pot, absence: true
  # Or with a custom message: absence: { message: "must be empty" }
end
```

| Options | What it checks |
|---------|----------------|
| `true` | Value is `nil`, empty string, empty collection, or only whitespace |

### Exclusion

“The answer cannot be one of these.”

```ruby
class ProcessProduct < CMDx::Task
  input :status, exclusion: { in: %w[recalled archived] }
end
```

| Options | Meaning |
|---------|---------|
| `:in` | Values (or a range) that are **not** allowed |
| `:within` | Same as `:in` |
| `:of_message` | Message when a single discrete value is wrong |
| `:in_message` | Message when a range check fails |
| `:within_message` | Same as `:in_message` |

### Format

“Must look like this pattern.” A bare regex is sugar for `{ with: regex }`.

```ruby
class ProcessProduct < CMDx::Task
  # Shorthand: bare Regexp → `{ with: regex }`
  input :sku, format: /\A[A-Z]{3}-[0-9]{4}\z/

  # Long form — same idea
  input :code, format: { with: /\A[A-Z]{3}-[0-9]{4}\z/ }
end
```

| Options | Meaning |
|---------|---------|
| `:with` | Must match this regex |
| `:without` | Must **not** match this regex |

### Inclusion

“Pick one of these friends.” Members are compared with `===`, so you can use regexes or classes in the list too.

```ruby
class ProcessProduct < CMDx::Task
  input :availability, inclusion: { in: %w[available limited] }
  # Enumerable members use `===`, so Regex and Class entries work:
  input :sku_or_code, inclusion: { in: [/\A[A-Z]{3}-\d{4}\z/, Integer] }
end
```

| Options | Meaning |
|---------|---------|
| `:in` | Allowed range (`#cover?`) or allowed list (`===` per item) |
| `:within` | Same as `:in` |
| `:of_message` | Message when a list member fails |
| `:in_message` | Message when a range fails |
| `:within_message` | Same as `:in_message` |

### Length

For anything that has a length (strings, arrays, etc.).

```ruby
class CreateBlogPost < CMDx::Task
  input :title, length: { within: 5..100 }
end
```

| Options | Meaning |
|---------|---------|
| `:within` | Length must fall in this range (inclusive) |
| `:not_within` | Length must **not** fall in this range |
| `:in` | Alias for `:within` |
| `:not_in` | Alias for `:not_within` |
| `:min` / `:gte` | Minimum length (inclusive) |
| `:max` / `:lte` | Maximum length (inclusive) |
| `:gt` | Length must be strictly greater than this |
| `:lt` | Length must be strictly less than this |
| `:is` / `:eq` | Exact length required |
| `:is_not` / `:not_eq` | Forbidden length |
| `:nil_message` | When the value doesn’t respond to `#length` |

Each rule can have a matching `<rule>_message` (e.g. `:min_message`). Aliases share the same message key (e.g. `:gte_message` → `:min_message`).

### Numeric

Same shape as length rules, but for numbers.

```ruby
class CreateBlogPost < CMDx::Task
  input :word_count, numeric: { min: 100 }
end
```

| Options | Meaning |
|---------|---------|
| `:within` | Value must be inside this range (inclusive) |
| `:not_within` | Value must stay outside this range |
| `:in` | Alias for `:within` |
| `:not_in` | Alias for `:not_within` |
| `:min` / `:gte` | Minimum value (inclusive) |
| `:max` / `:lte` | Maximum value (inclusive) |
| `:gt` | Must be strictly greater |
| `:lt` | Must be strictly less |
| `:is` / `:eq` | Must equal exactly |
| `:is_not` / `:not_eq` | Must not equal |
| `:nil_message` | When the value is `nil` |

Again, `<rule>_message` overrides exist; aliases share keys.

### Presence

“Something must be here.” Not the same as `required:` — see the section at the bottom.

```ruby
class CreateBlogPost < CMDx::Task
  input :content, presence: true
  # Or: presence: { message: "cannot be blank" }
end
```

| Options | What it checks |
|---------|----------------|
| `true` | Not `nil`, not an empty collection, not a whitespace-only string |

## Declarations

!!! warning "Important"

    To **fail** validation, return `CMDx::Validators::Failure.new("message")`. Anything else — even `false` or `nil` — counts as **pass**. Errors show up under the input’s **accessor** name (after `:as` / `:prefix` / `:suffix`).

### Proc or Lambda

Great for small, one-off rules:

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

Pull fancy rules into a named object — easier to test and reuse:

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

No `register`? Pass a `Symbol` (instance method), `Proc`, or callable straight to `validate:`. Use an array to chain several. Symbols get `(value)`; procs run with `instance_exec` and `(value)` (`self` is the task); `#call`-ables get `(value, task)`.

!!! warning "Watch the argument order"

    `:if` / `:unless` callables use `(task, value)`. Inline `:validate` callables use `(value, task)`. Same heads-up as inline `:coerce` — the arguments are **swapped**.

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

Don’t want a registered validator anymore? Drop it.

!!! warning

    One name per `deregister` call. Removing several? Call `deregister` several times.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## `required` vs `presence: true`

Easy to mix up — they solve different problems:

| Declaration | Caller **omits** the key entirely |
|-------------|-----------------------------------|
| `required :email` | You get “email is required.” Validators never run for that missing key. |
| `input :email, presence: true` | **No error** by default: optional + missing key skips validators. |
| `required :email, presence: true` | Missing key fails first; if the key exists, `presence` still runs on the value. |

!!! danger "Optional + presence alone"

    If an optional input ends up `nil`, validators (including `presence`) **do not** run — the pipeline stops after defaults. So `input :email, presence: true` does **nothing** when the caller never sends `email`. Use `required :email` (or both) when the key must be supplied.

## Error handling

Failed validations pile onto `task.errors` and the task returns failure; `result.reason` is a human sentence built from those messages. For the full story (nested inputs, etc.), see [Inputs - Error Handling](definitions.md#error-handling).
