# Parameters - Coercions

Parameter coercions provide automatic type conversion for task arguments, enabling
flexible input handling while ensuring type safety within task execution. Coercions
transform raw input values into expected types, supporting everything from simple
string-to-integer conversion to complex JSON parsing and custom type handling.

## Table of Contents

- [Coercion Fundamentals](#coercion-fundamentals)
  - [Available Coercion Types](#available-coercion-types)
  - [Basic Type Coercion](#basic-type-coercion)
- [Multiple Type Coercion](#multiple-type-coercion)
- [Advanced Coercion Examples](#advanced-coercion-examples)
  - [Array Coercion](#array-coercion)
  - [Hash Coercion](#hash-coercion)
  - [Boolean Coercion](#boolean-coercion)
  - [Date and Time Coercion](#date-and-time-coercion)
  - [Numeric Coercion](#numeric-coercion)
- [Coercion with Nested Parameters](#coercion-with-nested-parameters)
- [Coercion Error Handling](#coercion-error-handling)
  - [Single Type Coercion Errors](#single-type-coercion-errors)
  - [Multiple Type Coercion Errors](#multiple-type-coercion-errors)
- [Custom Coercion Options](#custom-coercion-options)
  - [Date/Time Format Options](#datetime-format-options)
  - [BigDecimal Precision Options](#bigdecimal-precision-options)

## Coercion Fundamentals

> [!NOTE]
> By default, parameters use the `:virtual` type which returns values unchanged. Type coercion is specified using the `:type` option and occurs automatically during parameter value resolution, before validation.

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
class ProcessUserDataTask < CMDx::Task

  required :user_id, type: :integer
  required :order_total, type: :float
  required :is_premium, type: :boolean
  required :notes, type: :string

  optional :product_tags, type: :array, default: []
  optional :preferences, type: :hash, default: {}
  optional :created_at, type: :datetime
  optional :delivery_date, type: :date

  def call
    user_id       #=> 12345 (integer from "12345")
    order_total   #=> 299.99 (float from "299.99")
    is_premium    #=> true (boolean from "true")
    notes         #=> "Rush delivery" (string)
    product_tags  #=> ["electronics", "phone"] (array from JSON)
    preferences   #=> {"notifications" => true} (hash from JSON)
    created_at    #=> DateTime object
    delivery_date #=> Date object
  end

end

# Coercion happens automatically
ProcessUserDataTask.call(
  user_id: "12345",
  order_total: "299.99",
  is_premium: "yes",
  notes: 67890,
  product_tags: "[\"electronics\",\"phone\"]",
  preferences: '{"notifications":true}',
  created_at: "2023-12-25 14:30:00",
  delivery_date: "2023-12-28"
)
```

## Multiple Type Coercion

> [!TIP]
> Parameters can specify multiple types for fallback coercion, attempting each type in order until one succeeds. This provides flexible input handling while maintaining type safety.

```ruby
class ProcessOrderDataTask < CMDx::Task

  # Try float first for precise calculations, fall back to integer
  required :amount, type: [:float, :integer]

  # Try hash first for structured data, fall back to string for raw data
  optional :shipping_info, type: [:hash, :string]

  # Complex fallback for timestamps
  optional :scheduled_at, type: [:datetime, :date, :string]

  def call
    amount        #=> 149.99 (float) or 150 (integer) depending on input
    shipping_info #=> {"address" => "123 Main St"} (hash) or "Express shipping" (string)
    scheduled_at  #=> DateTime, Date, or String depending on input format
  end

end

# Different inputs produce different coerced types
ProcessOrderDataTask.call(amount: "149.99")         # => 149.99 (float)
ProcessOrderDataTask.call(amount: "150")            # => 150 (integer)
ProcessOrderDataTask.call(shipping_info: '{"address":"123 Main St"}')  # => hash
ProcessOrderDataTask.call(shipping_info: "Express shipping")           # => string
```

## Advanced Coercion Examples

### Array Coercion

```ruby
class ProcessOrderItemsTask < CMDx::Task

  required :item_ids, type: :array
  optional :quantities, type: :array, default: []

  def call
    item_ids   #=> Array of product IDs
    quantities #=> Array of quantities or empty array
  end

end

# Array coercion handles multiple input formats
ProcessOrderItemsTask.call(item_ids: [101, 102, 103])         # => already array
ProcessOrderItemsTask.call(item_ids: "[101,102,103]")         # => from JSON string
ProcessOrderItemsTask.call(item_ids: "101")                   # => ["101"] (wrapped)
ProcessOrderItemsTask.call(item_ids: nil)                     # => [] (nil to empty)
```

### Hash Coercion

```ruby
class ProcessOrderConfigTask < CMDx::Task

  required :shipping_config, type: :hash
  optional :payment_options, type: :hash, default: {}

  def call
    shipping_config  #=> Hash with shipping configuration
    payment_options  #=> Hash with payment options or empty hash
  end

end

# Hash coercion supports multiple formats
ProcessOrderConfigTask.call(shipping_config: {carrier: "UPS", speed: "express"})
ProcessOrderConfigTask.call(shipping_config: '{"carrier":"UPS","speed":"express"}')
ProcessOrderConfigTask.call(shipping_config: [:carrier, "UPS", :speed, "express"])
```

### Boolean Coercion

```ruby
class ValidateUserSettingsTask < CMDx::Task

  required :email_notifications, type: :boolean
  required :is_active, type: :boolean
  optional :marketing_consent, type: :boolean, default: false

  def call
    email_notifications #=> true or false from various inputs
    is_active          #=> true or false
    marketing_consent  #=> true or false with default
  end

end

# Boolean coercion recognizes many text patterns
ValidateUserSettingsTask.call(email_notifications: "true")    # => true
ValidateUserSettingsTask.call(email_notifications: "yes")     # => true
ValidateUserSettingsTask.call(email_notifications: "1")       # => true
ValidateUserSettingsTask.call(email_notifications: "false")   # => false
ValidateUserSettingsTask.call(email_notifications: "no")      # => false
ValidateUserSettingsTask.call(email_notifications: "0")       # => false
```

### Date and Time Coercion

```ruby
class ProcessOrderScheduleTask < CMDx::Task

  required :order_date, type: :date
  required :created_at, type: :datetime
  optional :updated_at, type: :time

  # Custom format options for specific date/time formats
  optional :delivery_date, type: :date, format: "%Y-%m-%d"
  optional :pickup_time, type: :time, format: "%H:%M:%S"

  def call
    order_date    #=> Date object
    created_at    #=> DateTime object
    updated_at    #=> Time object
    delivery_date #=> Date parsed with custom format
    pickup_time   #=> Time parsed with custom format
  end

end

ProcessOrderScheduleTask.call(
  order_date: "2023-12-25",
  created_at: "2023-12-25 10:30:00",
  updated_at: "2023-12-25 10:30:00",
  delivery_date: "2023-12-28",
  pickup_time: "14:30:00"
)
```

### Numeric Coercion

```ruby
class CalculateOrderTotalsTask < CMDx::Task

  required :item_count, type: :integer
  required :subtotal, type: :float
  required :tax_rate, type: :float

  # High-precision for financial calculations
  optional :discount_amount, type: :big_decimal, precision: 4

  # For specialized calculations
  optional :shipping_ratio, type: :rational
  optional :complex_calculation, type: :complex

  def call
    item_count          #=> Integer from various formats
    subtotal            #=> Float for currency
    tax_rate            #=> Float for percentage
    discount_amount     #=> BigDecimal with specified precision
    shipping_ratio      #=> Rational number
    complex_calculation #=> Complex number
  end

end

CalculateOrderTotalsTask.call(
  item_count: "5",
  subtotal: "249.99",
  tax_rate: "0.0875",
  discount_amount: "25.0000",
  shipping_ratio: "1/10",
  complex_calculation: "1+2i"
)
```

## Coercion with Nested Parameters

> [!IMPORTANT]
> Coercion works seamlessly with nested parameter structures, applying type conversion at each level of the hierarchy.

```ruby
class ProcessOrderDetailsTask < CMDx::Task

  required :order, type: :hash do
    required :id, type: :integer
    required :total, type: :float
    required :items, type: :array

    optional :customer, type: :hash do
      required :id, type: :integer
      required :is_active, type: :boolean
      optional :created_at, type: :datetime
    end
  end

  def call
    order #=> Hash (coerced from JSON string if needed)

    # Nested coercions
    id    #=> Integer (from order.id)
    total #=> Float (from order.total)
    items #=> Array (from order.items)

    # Deep nested coercions
    if customer
      customer_id = id          # Integer (from order.customer.id)
      active_status = is_active # Boolean (from order.customer.is_active)
      created_time = created_at # DateTime (from order.customer.created_at)
    end
  end

end
```

## Coercion Error Handling

> [!WARNING]
> When coercion fails, CMDx provides detailed error information including the parameter name, attempted types, and specific failure reasons.

### Single Type Coercion Errors

```ruby
class ValidateUserProfileTask < CMDx::Task

  required :age, type: :integer
  required :salary, type: :float
  required :is_employed, type: :boolean

  def call
    # Task logic here
  end

end

# Invalid coercion inputs
result = ValidateUserProfileTask.call(
  age: "not-a-number",
  salary: "invalid-amount",
  is_employed: "maybe"
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "age could not coerce into an integer. salary could not coerce into a float. is_employed could not coerce into a boolean.",
#     messages: {
#       age: ["could not coerce into an integer"],
#       salary: ["could not coerce into a float"],
#       is_employed: ["could not coerce into a boolean"]
#     }
#   }
```

### Multiple Type Coercion Errors

```ruby
class ProcessFlexibleDataTask < CMDx::Task

  required :order_value, type: [:float, :integer]
  required :customer_data, type: [:hash, :array, :string]

  def call
    # Task logic here
  end

end

# Failed coercion with multiple types
result = ProcessFlexibleDataTask.call(
  order_value: "invalid-number",
  customer_data: Object.new
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "order_value could not coerce into one of: float, integer. customer_data could not coerce into one of: hash, array, string.",
#     messages: {
#       order_value: ["could not coerce into one of: float, integer"],
#       customer_data: ["could not coerce into one of: hash, array, string"]
#     }
#   }
```

## Custom Coercion Options

### Date/Time Format Options

```ruby
class ProcessCustomDateTask < CMDx::Task

  # US date format
  required :birth_date, type: :date, format: "%m/%d/%Y"

  # ISO datetime with timezone
  required :event_timestamp, type: :datetime, format: "%Y-%m-%d %H:%M:%S %Z"

  # 24-hour time format
  optional :meeting_time, type: :time, format: "%H:%M"

  def call
    birth_date      #=> Date parsed with MM/DD/YYYY format
    event_timestamp #=> DateTime with timezone
    meeting_time    #=> Time with hour:minute format
  end

end

ProcessCustomDateTask.call(
  birth_date: "12/25/1990",
  event_timestamp: "2023-12-25 10:30:00 UTC",
  meeting_time: "14:30"
)
```

### BigDecimal Precision Options

```ruby
class CalculatePricingTask < CMDx::Task

  required :base_price, type: :big_decimal
  required :tax_rate, type: :big_decimal, precision: 6

  def call
    base_price #=> BigDecimal with default precision
    tax_rate   #=> BigDecimal with 6-digit precision
  end

end
```

---

- **Prev:** [Namespacing](namespacing.md)
- **Next:** [Validations](validations.md)
