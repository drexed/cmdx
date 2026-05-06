# Inputs - Coercions

Coercion is CMDx’s way of saying: **“You gave me a string; I need an integer — let me fix that for you.”** Use `coerce:` on an input to turn messy external data into the shape your task expects.

App-wide custom coercers live in [Global Configuration](../configuration.md#coercions).

## Usage

Add `coerce:` to a declaration. CMDx runs it early in the pipeline (before transforms and validators):

```ruby
class ParseMetrics < CMDx::Task
  input :measurement_type, coerce: :symbol

  input :value, coerce: %i[rational big_decimal]

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

!!! tip

    Pass an **array** of coercers to try them in order. First one that succeeds wins — handy when input might be a string **or** already the right type.

## Built-in coercions

| Type | Options | In plain English | Examples |
|------|---------|------------------|----------|
| `:array` | | Turn into an array; JSON strings become real arrays; lone values get wrapped | `"val"` → `["val"]`<br>`"[1,2,3]"` → `[1, 2, 3]` |
| `:big_decimal` | `:precision` (default `14`) | Decimal math without float weirdness | `"123.456"` → `BigDecimal("123.456")` |
| `:boolean` | | Recognize common yes/no strings; `nil` / unknown strings fail | `"yes"` → `true`, `"no"` → `false` |
| `:complex` | `:imaginary` (default `0`) | Complex numbers from strings | `"1+2i"` → `Complex(1, 2)` |
| `:date` | `:strptime` | Parse strings or call `#to_date` when available | `"2024-01-23"` → `Date.new(2024, 1, 23)` |
| `:date_time` | `:strptime` | Like `:date`, but `DateTime` | `"2024-01-23 10:30"` → `DateTime.new(...)` |
| `:float` | | String → float | `"123.45"` → `123.45` |
| `:hash` | | `nil` → `{}`; JSON strings must decode to a Hash; else `#to_hash` / `#to_h` | `'{"a":1}'` → `{"a" => 1}` |
| `:integer` | | `Kernel#Integer` rules (hex/oct with prefixes) | `"0xFF"` → `255` |
| `:rational` | `:denominator` (default `1`) | Fractions from strings | `"1/2"` → `Rational(1, 2)` |
| `:string` | | Call `#to_s` | `123` → `"123"` |
| `:symbol` | | `#to_s.to_sym`; fails if there’s no `#to_s` | `"abc"` → `:abc` |
| `:time` | `:strptime` | Time parsing; numbers = Unix seconds | `"2024-01-23 10:30"` → `Time.new(...)` |

## Declarations

!!! warning "Success vs failure"

    Custom coercions return the **new value** on success, or `CMDx::Coercions::Failure.new("message")` on failure. Failures land on `task.errors` under the **accessor** name (after `:as` / `:prefix` / `:suffix`), not the raw declaration name.

!!! note "Two different call styles"

    **`register :coercion`** handlers get `(value, **options)` — so `precision:` and friends flow through. **Inline** `coerce:` callables (below) get `(value, task)` and **no** options hash.

### Proc or Lambda

Quick custom logic:

```ruby
class TransformCoordinates < CMDx::Task
  register :coercion, :geolocation, proc do |value, **options|
    Geolocation(value)
  rescue StandardError
    CMDx::Coercions::Failure.new("could not convert into a geolocation")
  end
end

class FormatTimeRange < CMDx::Task
  register :coercion, :time_range, ->(value, **options) {
    TimeRange(value)
  rescue StandardError
    CMDx::Coercions::Failure.new("could not convert into a time range")
  }
end
```

### Class or Module

Name it, test it, reuse it:

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

Skip `register` for one-offs: `Symbol` (instance method), `Proc`, or `#call`-able. Symbols get `(value)`; procs use `instance_exec` with `(value)`; callables get `(value, task)`:

```ruby
class TransformCoordinates < CMDx::Task
  input :latitude,  coerce: :parse_lat
  input :longitude, coerce: ->(v) { Float(v).round(6) }
  input :elevation, coerce: ElevationParser

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

Yank a registered coercion when you don’t need it:

!!! warning

    Same as validators: one `deregister` per name.

```ruby
class TransformCoordinates < CMDx::Task
  deregister :coercion, :geolocation
end
```

## Error handling

Failed coercion adds to `task.errors` and fails the run; `result.reason` summarizes it. Full lifecycle: [Inputs - Error Handling](definitions.md#error-handling).
