# Attribute Reference

For full documentation, see [docs/attributes/definitions.md](../docs/attributes/definitions.md), [docs/attributes/coercions.md](../docs/attributes/coercions.md), [docs/attributes/validations.md](../docs/attributes/validations.md), [docs/attributes/naming.md](../docs/attributes/naming.md), [docs/attributes/defaults.md](../docs/attributes/defaults.md), [docs/attributes/transformations.md](../docs/attributes/transformations.md).

## Declaration Methods

```ruby
required :name                        # required attribute
optional :name                        # optional attribute
attribute :name, required: true       # explicit required
attributes :a, :b, required: false    # multiple optional
```

Remove attributes inherited from a parent class:

```ruby
remove_attribute :legacy_field
remove_attributes :field_a, :field_b
```

## Full Option Signature

```ruby
attribute :name,
  required: true,              # required or optional (default: false)
  description: "...",          # metadata only (also accepts :desc)
  type: :string,               # single coercion type (symbol or class)
  types: [String, Symbol],     # multiple allowed types (class constants)
  default: "value",            # static, method name (symbol), or proc
  source: :context,            # where to read the value
  as: :alias_name,             # rename the accessor method
  prefix: true,                # prefix method with "context_" (true) or custom string
  suffix: true,                # suffix method with "_context" (true) or custom string
  transform: :strip,           # post-coercion transformation
  if: :condition?,             # conditional: only define if truthy
  unless: :condition?,         # conditional: only define if falsy
  presence: true,              # validation shorthand
  format: { with: /regex/ },   # validation shorthand
  length: { minimum: 1 },     # validation shorthand
  numeric: { greater_than: 0 },# validation shorthand
  inclusion: { in: [1, 2] },  # validation shorthand
  exclusion: { in: [0] },     # validation shorthand
  absence: true                # validation shorthand
```

## Source Options

Controls where the attribute value is read from:

```ruby
# Default: reads from context hash
attribute :user_id, source: :context

# Delegate to a task instance method
attribute :rate, source: :current_rate

# Proc (self is the task via instance_eval)
attribute :config, source: proc { load_config }

# Lambda
attribute :server, source: -> { Current.server }

# Class/module responding to .call (receives task as argument)
attribute :token, source: TokenGenerator
```

## Default Values

```ruby
# Static value
attribute :strategy, default: :incremental

# Method delegation
attribute :granularity, default: :default_granularity

# Proc (self is the task via instance_eval)
attribute :expire_hours, default: proc { Current.tenant.cache_duration || 24 }

# Lambda
attribute :compression, default: -> { Current.tenant.premium? ? "gzip" : "none" }
```

Defaults are only applied when the source value is `nil`.

## Type Coercion

### Built-in types

| Type | Coerces to | Notes |
|------|-----------|-------|
| `:array` | `Array` | Wraps non-arrays |
| `:big_decimal` | `BigDecimal` | |
| `:boolean` | `TrueClass`/`FalseClass` | Truthy/falsy conversion |
| `:complex` | `Complex` | |
| `:date` | `Date` | Parses strings |
| `:datetime` | `DateTime` | Parses strings |
| `:float` | `Float` | |
| `:hash` | `Hash` | |
| `:integer` | `Integer` | |
| `:rational` | `Rational` | |
| `:string` | `String` | Calls `to_s` |
| `:symbol` | `Symbol` | Calls `to_sym` |
| `:time` | `Time` | Parses strings |

### Usage

```ruby
required :count, type: :integer
required :active, type: :boolean
required :value, types: [Integer, Float]  # accepts either class
```

### Custom coercions

```ruby
class GeolocationCoercion
  def self.call(value, **_options)
    case value
    when String then Geolocation.parse(value)
    when Hash then Geolocation.new(**value)
    when Geolocation then value
    else raise CMDx::CoercionError, "cannot coerce #{value.class} to Geolocation"
    end
  end
end

# Register globally
CMDx.configure { |c| c.coercions = { geolocation: GeolocationCoercion } }

# Or per-task
register :coercion, :geolocation, GeolocationCoercion
```

## Validations

### Built-in validators

#### presence / absence

```ruby
required :name, presence: true
optional :deprecated_field, absence: true
```

#### format

```ruby
required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
required :slug, format: { without: /\s/ }
```

#### length

```ruby
required :code, length: { is: 6 }
required :name, length: { minimum: 2, maximum: 100 }
required :bio, length: { in: 10..500 }
```

#### numeric

```ruby
required :age, numeric: { greater_than: 0, less_than: 150 }
required :price, numeric: { greater_than_or_equal_to: 0 }
required :quantity, numeric: { odd: true }
required :score, numeric: { even: true, in: 0..100 }
```

#### inclusion / exclusion

```ruby
required :role, inclusion: { in: %w[admin member guest] }
required :status, exclusion: { in: %w[banned deleted] }
```

### Custom validators

```ruby
class ApiKeyValidator
  def self.call(value, **options)
    return if value.match?(/\Aak_[a-z0-9]{32}\z/)

    "must be a valid API key format"
  end
end

# Register globally
CMDx.configure { |c| c.validators = { api_key: ApiKeyValidator } }

# Or per-task
register :validator, :api_key, ApiKeyValidator

# Usage
required :key, api_key: true
```

## Naming

### prefix

```ruby
attribute :template, prefix: true           # method: context_template
attribute :format, prefix: "report_"        # method: report_format
```

### suffix

```ruby
attribute :branch, suffix: true             # method: branch_context
attribute :id, suffix: "_value"             # method: id_value
```

### as (alias)

```ruby
attribute :scheduled_at, as: :when
attribute :type, as: :category              # avoids reserved word conflicts
```

## Transforms

Applied after coercion, before validation:

```ruby
attribute :email, transform: :strip
attribute :email, transform: :downcase
attribute :tags, transform: :compact_blank
attribute :tags, transform: :uniq
attribute :score, type: :integer, transform: proc { |v| v.clamp(0, 100) }
attribute :data, transform: proc { |v| v.deep_symbolize_keys }
```

## Nested Attributes

```ruby
required :address do
  required :street, type: :string
  required :city, type: :string
  optional :zip, type: :string
end
```

## Shared Options with `with_options` (ActiveSupport)

Requires ActiveSupport (available in Rails, or `require "active_support/core_ext/object/with_options"` in plain Ruby):

```ruby
with_options type: :string, presence: true do
  required :first_name
  required :last_name
  required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

## Conditional Attributes

```ruby
required :billing_address, if: :paid_plan?
optional :coupon_code, unless: :enterprise?
attribute :sso_provider, if: -> { context.auth_method == "sso" }
```

## Inheritance

Child tasks inherit parent attributes and can add or remove them:

```ruby
class BaseTask < CMDx::Task
  required :tenant_id, type: :integer
end

class ChildTask < BaseTask
  required :user_id, type: :integer
  remove_attribute :tenant_id  # opt out of parent attribute
end
```
