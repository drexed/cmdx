# Parameters - Coercions

Parameter coercions provide automatic type conversion for task arguments, enabling flexible input handling while ensuring type safety. Coercions transform raw input values into expected types, supporting everything from simple string-to-integer conversion to complex JSON parsing and custom type handling.

## Table of Contents

- [Usage](#usage)
- [Built-in Coercions](#built-in-coercions)
- [Declarations](#declarations)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Removals](#removals)
- [Error Handling](#error-handling)

## Usage

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

## Declarations

```ruby
class PointCoercion
  def self.call(value, options = {})
    Point(value)
  rescue StandardError
    raise CoercionError, "could not convert into a point"
  end
end

class ProcessPayment < CMDx::Task
  register :coercion, :point, PointCoercion

  attribute :longitude, type: :point
end
```

## Built-in Coercions

| Type | Options | Description | Example |
|------|---------|-------------|---------|
| `:array` | | Array conversion, handles JSON | `"[1,2,3]"` → `[1, 2, 3]` |
| `:big_decimal` | `:precision` | High-precision decimal | `"123.45"` → `BigDecimal("123.45")` |
| `:boolean` | | True/false with text patterns | `"yes"` → `true` |
| `:complex` | | Complex numbers | `"1+2i"` → `Complex(1, 2)` |
| `:date` | `:strptime` | Date objects | `"2023-12-25"` → `Date` |
| `:datetime` | `:strptime` | DateTime objects | `"2023-12-25 10:30"` → `DateTime` |
| `:float` | | Floating-point | `"123.45"` → `123.45` |
| `:hash` | | Hash conversion, handles JSON | `'{"a":1}'` → `{"a" => 1}` |
| `:integer` | | Integer, handles hex/octal | `"0xFF"` → `255` |
| `:rational` | | Rational numbers | `"1/2"` → `Rational(1, 2)` |
| `:string` | | String conversion | `123` → `"123"` |
| `:symbol` | Symbol conversion | `"abc"` → `:abc` |
| `:time` | `:strptime` | Time objects | `"10:30:00"` → `Time` |

## Declarations

### Proc or Lambda

Use anonymous functions for simple callback logic:

```ruby
class FindLocation < CMDx::Task
  # Proc
  register :callback, :point, proc do |value, options = {}|
    begin
      Point(value)
    rescue StandardError
      raise CoercionError, "could not convert into a point"
    end
  end

  # Lambda
  register :callback, :point, ->(value, options = {}) {
    begin
      Point(value)
    rescue StandardError
      raise CoercionError, "could not convert into a point"
    end
  }
end
```

### Class or Module

For complex coercion logic, use classes or modules:

```ruby
class PointCoercion
  def self.call(value, options = {})
    Point(value)
  rescue StandardError
    raise CoercionError, "could not convert into a point"
  end
end

class FindLocation < CMDx::Task
  register :coercion, :point, PointCoercion

  attribute :longitude, type: :point
end
```

## Removals

Class and Module based declarations can be removed at a global and task level.

```ruby
class ProcessOrder < CMDx::Task
  # Class or Module (no instances)
  deregister :coercion, :point
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Error Handling

Coercion failures provide detailed error information including parameter paths, attempted types, and specific failure reasons.

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
