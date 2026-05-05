# Inputs - Coercions

Automatically convert inputs to expected types using `coerce:`.

See [Global Configuration](https://drexed.github.io/cmdx/configuration/#coercions) for custom coercion setup.

## Usage

Use `coerce:` to enable automatic coercion on a declared input:

```ruby
class ParseMetrics < CMDx::Task
  # Coerce into a symbol
  input :measurement_type, coerce: :symbol

  # Coerce into a rational, fall back to big decimal
  input :value, coerce: %i[rational big_decimal]

  # Coerce with options
  input :recorded_at, coerce: { date: { strptime: "%m-%d-%Y" } }

  def work
    measurement_type #=> :temperature
    recorded_at      #=> #<Date 2024-01-23>
    value            #=> Rational(493, 5)
  end
end

ParseMetrics.execute(
  measurement_type: "temperature",
  recorded_at: "01-23-2024",
  value: "98.6"
)
```

Tip

Pass an array to `coerce:` to attempt multiple types in order. CMDx returns the first successful coercion.

## Built-in Coercions

| Type           | Options                      | Description                                                                                      | Examples                                                   |
| -------------- | ---------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- |
| `:array`       |                              | Array conversion with JSON support; non-array JSON results fall back to wrapping                 | `"val"` → `["val"]` `"[1,2,3]"` → `[1, 2, 3]`              |
| `:big_decimal` | `:precision` (default `14`)  | High-precision decimal                                                                           | `"123.456"` → `BigDecimal("123.456")`                      |
| `:boolean`     |                              | Match text form against truthy/falsey sets; `nil` and unknown strings fail                       | `"yes"` → `true`, `"no"` → `false`                         |
| `:complex`     | `:imaginary` (default `0`)   | Complex numbers                                                                                  | `"1+2i"` → `Complex(1, 2)`                                 |
| `:date`        | `:strptime`                  | `Date.parse` on strings, `#to_date` on anything else that responds                               | `"2024-01-23"` → `Date.new(2024, 1, 23)`                   |
| `:date_time`   | `:strptime`                  | `DateTime.parse` on strings, `#to_datetime` on anything else that responds                       | `"2024-01-23 10:30"` → `DateTime.new(2024, 1, 23, 10, 30)` |
| `:float`       |                              | Floating-point numbers                                                                           | `"123.45"` → `123.45`                                      |
| `:hash`        |                              | `nil` → `{}`; strings are JSON-decoded (must decode to a Hash); falls back to `#to_hash`/`#to_h` | `'{"a":1}'` → `{"a" => 1}`                                 |
| `:integer`     |                              | Integer via `Kernel#Integer` (hex/octal with explicit prefix)                                    | `"0xFF"` → `255`, `"0o77"` → `63`                          |
| `:rational`    | `:denominator` (default `1`) | Rational numbers                                                                                 | `"1/2"` → `Rational(1, 2)`                                 |
| `:string`      |                              | String conversion                                                                                | `123` → `"123"`                                            |
| `:symbol`      |                              | `#to_s.to_sym`; fails when `value` has no `#to_s` (`BasicObject`)                                | `"abc"` → `:abc`                                           |
| `:time`        | `:strptime`                  | Time objects; `Numeric` treated as epoch seconds                                                 | `"2024-01-23 10:30"` → `Time.new(2024, 1, 23, 10, 30)`     |

## Declarations

Important

Custom coercions must return the coerced value on success or `CMDx::Coercions::Failure.new("message")` on failure. Returning a `Failure` records the message on `task.errors` keyed by the input's **accessor name** (post-`:as`/`:prefix`/`:suffix`) — not the original declaration name.

Call signatures

Registered coercions (via `register :coercion, ...`) receive `(value, **options)` and pick up per-declaration options like `precision:` or `strptime:`. Inline `:coerce` callables (see below) instead receive `(value, task)` and have no options hash.

### Proc or Lambda

Use anonymous functions for simple coercion logic:

```ruby
class TransformCoordinates < CMDx::Task
  # Proc
  register :coercion, :geolocation, proc do |value, **options|
    Geolocation(value)
  rescue StandardError
    CMDx::Coercions::Failure.new("could not convert into a geolocation")
  end
end

class FormatTimeRange < CMDx::Task
  # Lambda
  register :coercion, :time_range, ->(value, **options) {
    TimeRange(value)
  rescue StandardError
    CMDx::Coercions::Failure.new("could not convert into a time range")
  }
end
```

### Class or Module

Register custom coercion logic for specialized type handling:

```ruby
class GeolocationCoercion
  def self.call(value, **options)
    Geolocation(value)
  rescue StandardError
    CMDx::Coercions::Failure.new("could not convert into a geolocation")
  end
end

class TransformCoordinates < CMDx::Task
  register :coercion, :geolocation, GeolocationCoercion

  input :latitude, coerce: :geolocation
end
```

### Inline `:coerce` callable

For one-off coercions that don't need a registered name, pass a `Symbol` (instance method), `Proc`, or any callable directly to `coerce:`. Symbols receive `(value)`, Procs are `instance_exec`'d with `(value)` (`self` is the task), and `#call`-able objects receive `(value, task)`:

```ruby
class TransformCoordinates < CMDx::Task
  input :latitude,  coerce: :parse_lat                       # instance method
  input :longitude, coerce: ->(v) { Float(v).round(6) }      # lambda
  input :elevation, coerce: ElevationParser                  # callable: call(value, task)

  private

  def parse_lat(value)
    Float(value).clamp(-90.0, 90.0)
  end
end

class ElevationParser
  def self.call(value, task)
    Float(value).round(task.context.precision || 2)
  end
end
```

## Removals

Remove unwanted coercions:

Warning

Each `deregister` call removes one coercion. Use multiple calls for batch removals.

```ruby
class TransformCoordinates < CMDx::Task
  deregister :coercion, :geolocation
end
```

## Error Handling

Coercion failures accumulate on `task.errors` and surface as a failed result with the joined sentence as `result.reason`. See [Inputs - Error Handling](https://drexed.github.io/cmdx/inputs/definitions/#error-handling) for the full lifecycle.
