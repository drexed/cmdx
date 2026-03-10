# Attributes - Coercions

Automatically convert inputs to expected types. Coercions handle everything from simple string-to-integer conversions to JSON parsing.

See [Global Configuration](https://drexed.github.io/cmdx/configuration/#coercions) for custom coercion setup.

## Usage

Define attribute types to enable automatic coercion:

```ruby
class ParseMetrics < CMDx::Task
  # Coerce into a symbol
  attribute :measurement_type, type: :symbol

  # Coerce into a rational fallback to big decimal
  attribute :value, type: [:rational, :big_decimal]

  # Coerce with options
  attribute :recorded_at, type: :date, strptime: "%m-%d-%Y"

  def work
    measurement_type #=> :temperature
    recorded_at      #=> <Date 2024-01-23>
    value            #=> 98.6 (Float)
  end
end

ParseMetrics.execute(
  measurement_type: "temperature",
  recorded_at: "01-23-2020",
  value: "98.6"
)
```

Tip

Specify multiple coercion types for attributes that could be a variety of value formats. CMDx attempts each type in order until one succeeds.

## Built-in Coercions

| Type           | Options      | Description                        | Examples                                                   |
| -------------- | ------------ | ---------------------------------- | ---------------------------------------------------------- |
| `:array`       |              | Array conversion with JSON support | `"val"` → `["val"]` `"[1,2,3]"` → `[1, 2, 3]`              |
| `:big_decimal` | `:precision` | High-precision decimal             | `"123.456"` → `BigDecimal("123.456")`                      |
| `:boolean`     |              | Boolean with text patterns         | `"yes"` → `true`, `"no"` → `false`                         |
| `:complex`     |              | Complex numbers                    | `"1+2i"` → `Complex(1, 2)`                                 |
| `:date`        | `:strptime`  | Date objects                       | `"2024-01-23"` → `Date.new(2024, 1, 23)`                   |
| `:datetime`    | `:strptime`  | DateTime objects                   | `"2024-01-23 10:30"` → `DateTime.new(2024, 1, 23, 10, 30)` |
| `:float`       |              | Floating-point numbers             | `"123.45"` → `123.45`                                      |
| `:hash`        |              | Hash conversion with JSON support  | `'{"a":1}'` → `{"a" => 1}`                                 |
| `:integer`     |              | Integer with hex/octal support     | `"0xFF"` → `255`, `"077"` → `63`                           |
| `:rational`    |              | Rational numbers                   | `"1/2"` → `Rational(1, 2)`                                 |
| `:string`      |              | String conversion                  | `123` → `"123"`                                            |
| `:symbol`      |              | Symbol conversion                  | `"abc"` → `:abc`                                           |
| `:time`        | `:strptime`  | Time objects                       | `"10:30:00"` → `Time.new(2024, 1, 23, 10, 30)`             |

## Declarations

Important

Custom coercions must raise `CMDx::CoercionError` with a descriptive message.

### Proc or Lambda

Use anonymous functions for simple coercion logic:

```ruby
class TransformCoordinates < CMDx::Task
  # Proc
  register :coercion, :geolocation, proc do |value, options = {}|
    begin
      Geolocation(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a geolocation"
    end
  end

  # Lambda
  register :coercion, :geolocation, ->(value, options = {}) {
    begin
      Geolocation(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a geolocation"
    end
  }
end
```

### Class or Module

Register custom coercion logic for specialized type handling:

```ruby
class GeolocationCoercion
  def self.call(value, options = {})
    Geolocation(value)
  rescue StandardError
    raise CMDx::CoercionError, "could not convert into a geolocation"
  end
end

class TransformCoordinates < CMDx::Task
  register :coercion, :geolocation, GeolocationCoercion

  attribute :latitude, type: :geolocation
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

Coercion failures provide detailed error information including attribute paths, attempted types, and specific failure reasons:

```ruby
class AnalyzePerformance < CMDx::Task
  attribute  :iterations, type: :integer
  attribute  :score, type: [:float, :big_decimal]

  def work
    # Your logic here...
  end
end

result = AnalyzePerformance.execute(
  iterations: "not-a-number",
  score: "invalid-float"
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "iterations could not coerce into an integer. score could not coerce into one of: float, big_decimal.",
                #       messages: {
                #         iterations: ["could not coerce into an integer"],
                #         score: ["could not coerce into one of: float, big_decimal"]
                #       }
                #     }
                #   }
```
