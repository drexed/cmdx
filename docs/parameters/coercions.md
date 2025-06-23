# Parameters - Coercions

Parameter coercions provide automatic type conversion for task arguments, enabling
flexible input handling while ensuring type safety within task execution. Coercions
transform raw input values into expected types, supporting everything from simple
string-to-integer conversion to complex JSON parsing and custom type handling.

## Coercion Fundamentals

By default, parameters use the `:virtual` type which returns values unchanged.
Type coercion is specified using the `:type` option and occurs automatically
during parameter value resolution, before validation.

### Available Coercion Types

CMDx supports comprehensive type coercion for Ruby's built-in types:

| Type | Description | Example Input | Example Output |
|------|-------------|---------------|----------------|
| `:array` | Converts to Array, handles JSON strings | `"[1,2,3]"` | `[1, 2, 3]` |
| `:big_decimal` | High-precision decimal arithmetic | `"123.456"` | `BigDecimal("123.456")` |
| `:boolean` | True/false conversion with text patterns | `"true"`, `"yes"`, `"1"` | `true` |
| `:complex` | Complex number conversion | `"1+2i"` | `Complex(1, 2)` |
| `:date` | Date object conversion | `"2023-12-25"` | `Date.new(2023, 12, 25)` |
| `:datetime` | DateTime object conversion | `"2023-12-25 10:30"` | `DateTime` object |
| `:float` | Floating-point number conversion | `"123.45"` | `123.45` |
| `:hash` | Hash conversion, handles JSON strings | `'{"a":1}'` | `{"a" => 1}` |
| `:integer` | Integer conversion, handles various formats | `"123"`, `"0xFF"` | `123`, `255` |
| `:rational` | Rational number conversion | `"1/2"`, `0.5` | `Rational(1, 2)` |
| `:string` | String conversion for any object | `123`, `:symbol` | `"123"`, `"symbol"` |
| `:time` | Time object conversion | `"2023-12-25 10:30"` | `Time` object |
| `:virtual` | No conversion (default) | `anything` | `anything` |

### Basic Type Coercion

```ruby
class TypeCoercionTask < CMDx::Task

  # Single type coercions
  required :user_id, type: :integer
  required :price, type: :float
  required :active, type: :boolean
  required :description, type: :string

  # Array and hash coercions
  optional :tags, type: :array, default: []
  optional :metadata, type: :hash, default: {}

  # Date and time coercions
  optional :created_at, type: :datetime
  optional :expires_on, type: :date

  def call
    user_id      #=> 123 (integer from "123")
    price        #=> 99.99 (float from "99.99")
    active       #=> true (boolean from "true")
    description  #=> "Product description" (string)
    tags         #=> ["tag1", "tag2"] (array from JSON or existing array)
    metadata     #=> {"key" => "value"} (hash from JSON or existing hash)
    created_at   #=> DateTime object
    expires_on   #=> Date object
  end

end

# Coercion happens automatically
TypeCoercionTask.call(
  user_id: "123",           # String to integer
  price: "99.99",           # String to float
  active: "yes",            # String to boolean
  description: 12345,       # Integer to string
  tags: "[\"tag1\",\"tag2\"]", # JSON string to array
  metadata: '{"key":"value"}', # JSON string to hash
  created_at: "2023-12-25 10:30:00",
  expires_on: "2023-12-25"
)
```

## Multiple Type Coercion

Parameters can specify multiple types for fallback coercion, attempting each
type in order until one succeeds:

```ruby
class FlexibleCoercionTask < CMDx::Task

  # Try float first, fall back to integer
  required :numeric_value, type: [:float, :integer]

  # Try hash first, fall back to string
  optional :flexible_data, type: [:hash, :string]

  # Complex fallback chain
  optional :mixed_input, type: [:datetime, :date, :string]

  def call
    # Coercion attempts types in order
    numeric_value  #=> 123.45 (float) or 123 (integer) depending on input
    flexible_data  #=> {"key" => "value"} (hash) or "raw string" (string)
    mixed_input    #=> DateTime, Date, or String depending on input format
  end

end

# Different inputs produce different coerced types
FlexibleCoercionTask.call(numeric_value: "123.45")    # => 123.45 (float)
FlexibleCoercionTask.call(numeric_value: "123")       # => 123 (integer)
FlexibleCoercionTask.call(flexible_data: '{"a":1}')   # => {"a" => 1} (hash)
FlexibleCoercionTask.call(flexible_data: "raw text")  # => "raw text" (string)
```

## Advanced Coercion Examples

### Array Coercion

```ruby
class ArrayCoercionTask < CMDx::Task

  required :items, type: :array
  optional :numbers, type: :array, default: []

  def call
    items    #=> Array from various input formats
    numbers  #=> Array of numbers or empty array
  end

end

# Array coercion handles multiple input formats
ArrayCoercionTask.call(items: [1, 2, 3])              # => [1, 2, 3] (already array)
ArrayCoercionTask.call(items: "[1,2,3]")              # => [1, 2, 3] (JSON string)
ArrayCoercionTask.call(items: "single")               # => ["single"] (wrapped)
ArrayCoercionTask.call(items: nil)                    # => [] (nil to empty array)
```

### Hash Coercion

```ruby
class HashCoercionTask < CMDx::Task

  required :config, type: :hash
  optional :settings, type: :hash, default: {}

  def call
    config   #=> Hash from various input formats
    settings #=> Hash or empty hash
  end

end

# Hash coercion supports multiple formats
HashCoercionTask.call(config: {a: 1, b: 2})           # => {a: 1, b: 2} (already hash)
HashCoercionTask.call(config: '{"a":1,"b":2}')        # => {"a" => 1, "b" => 2} (JSON)
HashCoercionTask.call(config: [:a, 1, :b, 2])         # => {a: 1, b: 2} (array to hash)
```

### Boolean Coercion

```ruby
class BooleanCoercionTask < CMDx::Task

  required :enabled, type: :boolean
  required :active, type: :boolean
  optional :verified, type: :boolean, default: false

  def call
    enabled  #=> true or false from various input formats
    active   #=> true or false
    verified #=> true or false with default
  end

end

# Boolean coercion recognizes many text patterns
BooleanCoercionTask.call(enabled: "true")     # => true
BooleanCoercionTask.call(enabled: "yes")      # => true
BooleanCoercionTask.call(enabled: "1")        # => true
BooleanCoercionTask.call(enabled: "t")        # => true
BooleanCoercionTask.call(enabled: "false")    # => false
BooleanCoercionTask.call(enabled: "no")       # => false
BooleanCoercionTask.call(enabled: "0")        # => false
BooleanCoercionTask.call(enabled: "f")        # => false
```

### Date and Time Coercion

```ruby
class DateTimeCoercionTask < CMDx::Task

  required :start_date, type: :date
  required :created_at, type: :datetime
  optional :updated_at, type: :time

  # Custom format options for date/time coercion
  optional :custom_date, type: :date, format: "%Y-%m-%d"
  optional :custom_time, type: :time, format: "%H:%M:%S"

  def call
    start_date   #=> Date object
    created_at   #=> DateTime object
    updated_at   #=> Time object
    custom_date  #=> Date parsed with custom format
    custom_time  #=> Time parsed with custom format
  end

end

# Date/time coercion handles various formats
DateTimeCoercionTask.call(
  start_date: "2023-12-25",
  created_at: "2023-12-25 10:30:00",
  updated_at: "2023-12-25 10:30:00",
  custom_date: "2023-12-25",
  custom_time: "10:30:00"
)
```

### Numeric Coercion

```ruby
class NumericCoercionTask < CMDx::Task

  # Integer coercion handles various formats
  required :count, type: :integer
  required :hex_value, type: :integer  # Handles hex, binary, octal

  # Float coercion with precision
  required :price, type: :float
  required :rate, type: :float

  # High-precision decimal
  optional :precise_amount, type: :big_decimal, precision: 4

  # Rational numbers
  optional :fraction, type: :rational

  # Complex numbers
  optional :complex_num, type: :complex

  def call
    count          #=> Integer from various formats
    hex_value      #=> Integer from hex/binary/octal strings
    price          #=> Float
    rate           #=> Float
    precise_amount #=> BigDecimal with specified precision
    fraction       #=> Rational number
    complex_num    #=> Complex number
  end

end

# Numeric coercion examples
NumericCoercionTask.call(
  count: "123",           # => 123
  hex_value: "0xFF",      # => 255
  price: "99.99",         # => 99.99
  rate: "0.15",           # => 0.15
  precise_amount: "123.4567",  # => BigDecimal with precision
  fraction: "1/2",        # => Rational(1, 2)
  complex_num: "1+2i"     # => Complex(1, 2)
)
```

## Coercion with Nested Parameters

Coercion works seamlessly with nested parameter structures:

```ruby
class NestedCoercionTask < CMDx::Task

  required :order, type: :hash do
    required :id, type: :integer
    required :total, type: :float
    required :items, type: :array

    optional :customer, type: :hash do
      required :id, type: :integer
      required :active, type: :boolean
      optional :created_at, type: :datetime
    end
  end

  def call
    # Parent coercion
    order        #=> Hash (coerced from JSON string if needed)

    # Nested coercions
    id           #=> Integer (from order.id)
    total        #=> Float (from order.total)
    items        #=> Array (from order.items)

    # Deep nested coercions
    if customer
      customer_id = id       # Integer (from order.customer.id)
      active_status = active # Boolean (from order.customer.active)
      created_time = created_at # DateTime (from order.customer.created_at)
    end
  end

end
```

## Coercion Error Handling

When coercion fails, detailed error information is provided:

### Single Type Coercion Errors

```ruby
class CoercionErrorTask < CMDx::Task

  required :age, type: :integer
  required :price, type: :float
  required :active, type: :boolean

  def call
    # Task logic here
  end

end

# Invalid coercion inputs
result = CoercionErrorTask.call(
  age: "not-a-number",
  price: "invalid-float",
  active: "maybe"
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "age could not coerce into an integer. price could not coerce into a float. active could not coerce into a boolean.",
#     messages: {
#       age: ["could not coerce into an integer"],
#       price: ["could not coerce into a float"],
#       active: ["could not coerce into a boolean"]
#     }
#   }
```

### Multiple Type Coercion Errors

```ruby
class MultiTypeCoercionTask < CMDx::Task

  required :flexible_number, type: [:float, :integer]
  required :mixed_data, type: [:hash, :array, :string]

  def call
    # Task logic here
  end

end

# Failed coercion with multiple types
result = MultiTypeCoercionTask.call(
  flexible_number: "invalid",
  mixed_data: Object.new  # Cannot coerce to any of the specified types
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "flexible_number could not coerce into one of: float, integer. mixed_data could not coerce into one of: hash, array, string.",
#     messages: {
#       flexible_number: ["could not coerce into one of: float, integer"],
#       mixed_data: ["could not coerce into one of: hash, array, string"]
#     }
#   }
```

## Custom Coercion Options

Some coercion types support additional options for customization:

### Date/Time Format Options

```ruby
class CustomFormatTask < CMDx::Task

  # Custom date format
  required :birth_date, type: :date, format: "%m/%d/%Y"

  # Custom datetime format
  required :event_time, type: :datetime, format: "%Y-%m-%d %H:%M:%S %Z"

  # Custom time format
  optional :meeting_time, type: :time, format: "%H:%M"

  def call
    birth_date   #=> Date parsed with MM/DD/YYYY format
    event_time   #=> DateTime with timezone
    meeting_time #=> Time with hour:minute format
  end

end

CustomFormatTask.call(
  birth_date: "12/25/1990",
  event_time: "2023-12-25 10:30:00 UTC",
  meeting_time: "14:30"
)
```

### BigDecimal Precision Options

```ruby
class PrecisionTask < CMDx::Task

  # Default precision
  required :amount, type: :big_decimal

  # Custom precision
  required :rate, type: :big_decimal, precision: 6

  def call
    amount #=> BigDecimal with default precision
    rate   #=> BigDecimal with 6-digit precision
  end

end
```

## Coercion Best Practices

### Type Selection Strategy

```ruby
class BestPracticeTask < CMDx::Task

  # Use specific types for known data
  required :user_id, type: :integer
  required :email, type: :string

  # Use multiple types for flexible inputs
  optional :quantity, type: [:integer, :float]  # Allow whole or decimal numbers

  # Use virtual for complex objects that shouldn't be coerced
  required :user_object, type: :virtual

  # Use appropriate defaults with coercion
  optional :active, type: :boolean, default: true
  optional :tags, type: :array, default: []

  def call
    # Clean, predictable types available
  end

end
```

### Error Prevention

```ruby
class SafeCoercionTask < CMDx::Task

  # Validate after coercion for additional safety
  required :age,
    type: :integer,
    numeric: { min: 0, max: 150 }

  # Use multiple types with validation
  required :score,
    type: [:float, :integer],
    numeric: { within: 0.0..100.0 }

  # Provide defaults for optional coerced parameters
  optional :metadata,
    type: :hash,
    default: {},
    custom: { validator: MetadataValidator }

  def call
    # Coerced and validated parameters
  end

end
```

### Performance Considerations

- **Virtual type**: Use `:virtual` for parameters that don't need coercion
- **Multiple types**: Order types by likelihood of success for better performance
- **Complex coercions**: Cache results of expensive coercions when possible
- **Validation**: Combine coercion with validation for comprehensive parameter handling

### Debugging Coercion Issues

- **Check input types**: Verify the actual type of input values
- **Test edge cases**: Test coercion with nil, empty strings, and invalid formats
- **Use multiple types**: Provide fallback types for flexible input handling
- **Clear error messages**: Coercion errors include the attempted types for debugging

---

- **Prev:** [Namespacing](https://github.com/drexed/cmdx/blob/main/docs/parameters/namespacing.md)
- **Next:** [Validations](https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md)
