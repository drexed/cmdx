# Inputs Reference

Docs: [docs/inputs/definitions.md](../../docs/inputs/definitions.md), [docs/inputs/coercions.md](../../docs/inputs/coercions.md), [docs/inputs/validations.md](../../docs/inputs/validations.md), [docs/inputs/naming.md](../../docs/inputs/naming.md), [docs/inputs/defaults.md](../../docs/inputs/defaults.md), [docs/inputs/transformations.md](../../docs/inputs/transformations.md).

## Declaration

```ruby
required :name                       # required input
optional :name                       # optional input
input    :name                       # alias for inputs (optional by default)
inputs   :a, :b, required: false     # multiple

deregister :input, :legacy_field     # remove inherited input + its reader
```

`input` is an alias of `inputs`; both accept one or more names and keyword options. `required`/`optional` are shorthands that set `required:` on top of any options passed.

## Resolution Pipeline

Per input, in order:

1. **Fetch** via `:source` (default `:context`).
2. **Default** applied when the fetched value is `nil`.
3. **Coerce** via `:coerce` (one or more coercions; the first successful one wins).
4. **Transform** via `:transform`.
5. **Validate** — declared validator shorthands and inline `:validate` callables.

## Options

| Option | Description |
|--------|-------------|
| `required:` | `true`/`false`. Required missing key adds `cmdx.attributes.required` error. |
| `description:` / `desc:` | Metadata for `inputs_schema`. |
| `coerce:` | Symbol, array of symbols, Hash with per-coercion options, Proc, or any `#call`-able. |
| `default:` | Static value, Symbol (method), Proc (`instance_exec`), or `#call(task)`-able. |
| `source:` | `:context` (default), Symbol (method), Proc, or `#call(task)`-able. |
| `as:` | Overrides reader method name. |
| `prefix:` | `true` → `<source>_`, or a String prefix. |
| `suffix:` | `true` → `_<source>`, or a String suffix. |
| `transform:` | Symbol, Proc, or `#call(value, task)`. Applied post-coercion, pre-validation. |
| `if:` / `unless:` | Gate declaration-required check. Signature `(task)` — NOT `(task, value)`. |
| `presence:`, `absence:`, `format:`, `length:`, `numeric:`, `inclusion:`, `exclusion:` | Validator shorthands. |
| `validate:` | Inline validator (Symbol/Proc/`#call`-able). |

## Sources

```ruby
required :user_id                              # context[:user_id]
required :user_id, source: :context            # same as above
required :rate,    source: :current_rate       # task.current_rate (instance method)
required :config,  source: proc { load }       # instance_exec on task
required :server,  source: -> { Current.server }
required :token,   source: TokenGenerator      # TokenGenerator.call(task)
```

When the source object responds to `#key?`, existence is disambiguated from an explicit `nil`. Otherwise (bare `#[]`), an explicit `nil` is treated as "not provided" and triggers the default.

## Defaults

```ruby
optional :strategy,     default: :incremental                    # static
optional :granularity,  default: :default_granularity             # method
optional :expire_hours, default: proc { tenant.cache_duration }   # Proc (instance_exec)
optional :compression,  default: -> { premium? ? "gzip" : "none" }
optional :client,       default: TokenGenerator                   # #call(task)
```

Defaults apply only when the fetched value is `nil`.

## Coercions

### Built-ins

| Symbol | Target |
|--------|--------|
| `:array` | `Array` (wraps non-Arrays) |
| `:big_decimal` | `BigDecimal` |
| `:boolean` | `TrueClass` / `FalseClass` |
| `:complex` | `Complex` |
| `:date` | `Date` |
| `:date_time` | `DateTime` |
| `:float` | `Float` |
| `:hash` | `Hash` |
| `:integer` | `Integer` |
| `:rational` | `Rational` |
| `:string` | `String` |
| `:symbol` | `Symbol` |
| `:time` | `Time` |

### Usage

```ruby
required :count, coerce: :integer
required :tags,  coerce: :array
required :value, coerce: %i[rational big_decimal]                 # first success wins
required :recorded_at, coerce: { date: { strptime: "%m-%d-%Y" } } # per-coercion options
required :temp,  coerce: ->(v) { Kelvin.parse(v) }                # inline callable
```

Inline coerce callable arity:

| Form | Invocation |
|------|------------|
| `Symbol` | `task.send(name, value)` |
| `Proc` | `task.instance_exec(value, &proc)` |
| `#call`-able | `callable.call(value, task)` |

### Custom coercions

```ruby
class GeolocationCoercion
  def self.call(value, _options = {})
    case value
    when String    then Geolocation.parse(value)
    when Hash      then Geolocation.new(**value)
    when Geolocation then value
    else CMDx::Coercions::Failure.new("cannot coerce #{value.class} to Geolocation")
    end
  end
end

# Globally
CMDx.configure { |c| c.coercions.register(:geolocation, GeolocationCoercion) }

# Per task
register :coercion, :geolocation, GeolocationCoercion

required :origin, coerce: :geolocation
```

Return `CMDx::Coercions::Failure.new("message")` to fail; any other value is treated as the coerced result.

## Validators

Shorthands can accept a normalized short form: `Hash` → options, `Array` → `{ in: array }`, `Regexp` → `{ with: regexp }`, `true` → `{}`, `false`/`nil` → skip.

### Built-in validators

```ruby
required :name,      presence: true
optional :honey_pot, absence:  true
required :email,     format:   { with: URI::MailTo::EMAIL_REGEXP }
required :slug,      format:   { without: /\s/ }
required :code,      length:   { is: 6 }
required :name,      length:   { min: 2, max: 100 }
required :bio,       length:   { within: 10..500 }
required :age,       numeric:  { gt: 0, lt: 150 }
required :price,     numeric:  { gte: 0 }
required :score,     numeric:  { within: 0..100 }
required :role,      inclusion: { in: %w[admin member guest] }
required :status,    exclusion: { in: %w[banned deleted] }
```

Numeric/length keys: `:min`/`:gte`, `:max`/`:lte`, `:gt`, `:lt`, `:is`/`:eq`, `:is_not`/`:not_eq`, `:within`/`:in`, `:not_within`/`:not_in`.

Common options for every shorthand: `:allow_nil`, `:message`, `:if`, `:unless`, plus per-rule `<rule>_message` overrides.

### `:if` / `:unless` arity on validators

Gates on the validator side receive the **value**:

| Form | Invocation | Signature |
|------|------------|-----------|
| Symbol | `task.send(name, value)` | `def name(value)` |
| Proc | `task.instance_exec(value, &proc)` | `->(value) { }` |
| `#call`-able | `callable.call(task, value)` | `def call(task, value)` |

### Custom validators

```ruby
class ApiKeyValidator
  def self.call(value, options = {})
    return if value.match?(/\Aak_[a-z0-9]{32}\z/)

    CMDx::Validators::Failure.new(options[:message] || "invalid API key")
  end
end

# Globally
CMDx.configure { |c| c.validators.register(:api_key, ApiKeyValidator) }

# Per task
register :validator, :api_key, ApiKeyValidator

required :token, api_key: true
```

### Inline `:validate`

Accepts Symbol, Proc, `#call`-able, or an Array chain.

```ruby
required :email,
  validate: ->(value) {
    CMDx::Validators::Failure.new("invalid") unless value.include?("@")
  }

required :digits, validate: [:first_check, ->(v) { ... }, MyValidator]
```

Arity asymmetry (inverted from the `:if`/`:unless` form):

| Form | Invocation |
|------|------------|
| Symbol | `task.send(name, value)` |
| Proc | `task.instance_exec(value, &proc)` |
| `#call`-able | `callable.call(value, task)` |

Return a `CMDx::Validators::Failure` to fail the input; anything else (including `nil`) passes.

## Naming

```ruby
input :template,    prefix: true          # context_template
input :format,      prefix: "report_"     # report_format
input :branch,      suffix: true          # branch_context
input :id,          suffix: "_value"      # id_value
input :scheduled_at, as: :scheduled       # scheduled
input :type,        as: :category         # avoids reserved conflicts
```

Naming collisions with already-defined methods raise `CMDx::DefinitionError` at registration.

## Transforms

Applied post-coercion, pre-validation.

```ruby
optional :email, coerce: :string, transform: :downcase
optional :tags,  coerce: :array,  transform: :uniq
optional :score, coerce: :integer, transform: proc { |v| v.clamp(0, 100) }
optional :data,  transform: ->(v, _task) { v.deep_symbolize_keys }
```

Arity:

| Form | Invocation |
|------|------------|
| Symbol (responded to by value) | `value.send(name)` |
| Symbol (task method) | `task.send(name, value)` |
| Proc | `task.instance_exec(value, &proc)` |
| `#call`-able | `callable.call(value, task)` |

## Conditional declaration

```ruby
required :billing_address, if: :paid_plan?
optional :coupon_code,     unless: :enterprise?
input    :sso_provider,    if: -> { context.auth_method == "sso" }
```

Gates at the **input** level receive `(task)` — not `(task, value)` — because they're evaluated before the value exists.

## Nested inputs

```ruby
required :address do
  required :street, coerce: :string
  required :city,   coerce: :string
  optional :zip,    coerce: :string
end
```

Each nested input generates its own reader. Children are resolved from the parent's coerced value (anything responding to `#[]`). Children DO NOT receive `:source`; they read from the parent.

## Shared options (ActiveSupport)

```ruby
with_options coerce: :string, presence: true do
  required :first_name
  required :last_name
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

Requires ActiveSupport (`require "active_support/core_ext/object/with_options"` in plain Ruby).

## Inheritance

Subclasses inherit the parent's inputs via a lazy `dup`. Use `deregister :input, :name` to remove specific inputs.

```ruby
class BaseTask < CMDx::Task
  required :tenant_id, coerce: :integer
end

class ChildTask < BaseTask
  required :user_id, coerce: :integer
  deregister :input, :tenant_id
end
```

Deregister targets the original declared name, not the accessor name (so a `:scheduled_at` input declared with `as: :scheduled` is still removed by `:scheduled_at`).

## Schema

```ruby
MyTask.inputs_schema
# => { tenant_id: { name: :tenant_id, description: nil, required: true, options: {...}, children: [] }, ... }
```
