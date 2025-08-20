# Parameters - Coercions

Parameter coercions automatically convert task arguments to expected types, ensuring type safety while providing flexible input handling. Coercions transform raw input values into the specified types, supporting simple conversions like string-to-integer and complex operations like JSON parsing.

## Table of Contents

- [Usage](#usage)
- [Built-in Coercions](#built-in-coercions)
- [Declarations](#declarations)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Removals](#removals)
- [Error Handling](#error-handling)

## Usage

Define attribute types to enable automatic coercion:

```ruby
class ProcessPayment < CMDx::Task
  # Coerce into a date
  attribute :paid_with, type: :symbol

  # Coerce into a float fallback to big decimal
  attribute :total, type: [:float, :big_decimal]

  # Coerce with options
  attribute :paid_on, type: :date, strptime: "%m-%d-%Y"

  def work
    paid_with #=> :amex
    paid_on   #=> <Date 2024-01-23>
    total     #=> 34.99 (Float)
  end
end

ProcessPayment.execute(paid_with: "amex", paid_on: "01-23-2020", total: "34.99")
```

> [!TIP]
> Specify multiple types for fallback coercion. CMDx attempts each type in order until one succeeds.

## Built-in Coercions

| Type | Options | Description | Examples |
|------|---------|-------------|----------|
| `:array` | | Array conversion with JSON support | `"val"` → `["val"]`<br>`"[1,2,3]"` → `[1, 2, 3]` |
| `:big_decimal` | `:precision` | High-precision decimal | `"123.456"` → `BigDecimal("123.456")` |
| `:boolean` | | Boolean with text patterns | `"yes"` → `true`, `"no"` → `false` |
| `:complex` | | Complex numbers | `"1+2i"` → `Complex(1, 2)` |
| `:date` | `:strptime` | Date objects | `"2024-01-23"` → `Date.new(2024, 1, 23)` |
| `:datetime` | `:strptime` | DateTime objects | `"2024-01-23 10:30"` → `DateTime.new(2024, 1, 23, 10, 30)` |
| `:float` | | Floating-point numbers | `"123.45"` → `123.45` |
| `:hash` | | Hash conversion with JSON support | `'{"a":1}'` → `{"a" => 1}` |
| `:integer` | | Integer with hex/octal support | `"0xFF"` → `255`, `"077"` → `63` |
| `:rational` | | Rational numbers | `"1/2"` → `Rational(1, 2)` |
| `:string` | | String conversion | `123` → `"123"` |
| `:symbol` | | Symbol conversion | `"abc"` → `:abc` |
| `:time` | `:strptime` | Time objects | `"10:30:00"` → `Time.new(2024, 1, 23, 10, 30)` |

## Declarations

> [!IMPORTANT]
> Coercions must raise a CMDx::CoercionError and its message is used as part of the fault reason and metadata.

### Proc or Lambda

Use anonymous functions for simple coercion logic:

```ruby
class FindLocation < CMDx::Task
  # Proc
  register :callback, :point, proc do |value, options = {}|
    begin
      Point(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a point"
    end
  end

  # Lambda
  register :callback, :point, ->(value, options = {}) {
    begin
      Point(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a point"
    end
  }
end
```

### Class or Module

Register custom coercion logic for specialized type handling:

```ruby
class PointCoercion
  def self.call(value, options = {})
    Point(value)
  rescue StandardError
    raise CMDx::CoercionError, "could not convert into a point"
  end
end

class FindLocation < CMDx::Task
  register :coercion, :point, PointCoercion

  attribute :longitude, type: :point
end
```

## Removals

Remove custom coercions when no longer needed:

```ruby
class ProcessOrder < CMDx::Task
  deregister :coercion, :point
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Error Handling

Coercion failures provide detailed error information including parameter paths, attempted types, and specific failure reasons:

```ruby
class ProcessData < CMDx::Task
  attribute  :count, type: :integer
  attribute  :amount, type: [:float, :big_decimal]

  def work
    # Your logic here...
  end
end

result = ProcessData.execute(count: "not-a-number", amount: "invalid-float")

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "count could not coerce into an integer. amount could not coerce into one of: float, big_decimal."
result.metadata #=> {
                #     messages: {
                #       count: ["could not coerce into an integer"],
                #       amount: ["could not coerce into one of: float, big_decimal"]
                #     }
                #   }
```

---

- **Prev:** [Parameters - Namespacing](namespacing.md)
- **Next:** [Parameters - Validations](validations.md)
