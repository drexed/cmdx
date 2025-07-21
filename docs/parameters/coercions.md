# Parameters - Coercions

Parameter coercions provide automatic type conversion for task arguments, enabling flexible input handling while ensuring type safety. Coercions transform raw input values into expected types, supporting everything from simple string-to-integer conversion to complex JSON parsing and custom type handling.

## Table of Contents

- [TLDR](#tldr)
- [Coercion Fundamentals](#coercion-fundamentals)
- [Multiple Type Coercion](#multiple-type-coercion)
- [Advanced Examples](#advanced-examples)
- [Coercion with Nested Parameters](#coercion-with-nested-parameters)
- [Error Handling](#error-handling)
- [Custom Coercion Options](#custom-coercion-options)
- [Custom Coercions](#custom-coercions)

## TLDR

```ruby
# Basic type coercion
required :user_id, type: :integer     # "123" → 123
required :active, type: :boolean      # "true" → true
required :tags, type: :array          # "[1,2,3]" → [1, 2, 3]

# Multiple type fallback
required :amount, type: [:float, :integer]  # Tries float, then integer

# Custom formats
required :created_at, type: :date, format: "%Y-%m-%d"

# No conversion (default)
required :raw_data, type: :virtual    # Returns unchanged
```

## Coercion Fundamentals

> [!NOTE]
> Parameters use `:virtual` type by default (no conversion). Coercion occurs automatically during parameter resolution, before validation.

### Available Types

| Type | Description | Example |
|------|-------------|---------|
| `:array` | Array conversion, handles JSON | `"[1,2,3]"` → `[1, 2, 3]` |
| `:big_decimal` | High-precision decimal | `"123.45"` → `BigDecimal("123.45")` |
| `:boolean` | True/false with text patterns | `"yes"` → `true` |
| `:complex` | Complex numbers | `"1+2i"` → `Complex(1, 2)` |
| `:date` | Date objects | `"2023-12-25"` → `Date` |
| `:datetime` | DateTime objects | `"2023-12-25 10:30"` → `DateTime` |
| `:float` | Floating-point | `"123.45"` → `123.45` |
| `:hash` | Hash conversion, handles JSON | `'{"a":1}'` → `{"a" => 1}` |
| `:integer` | Integer, handles hex/octal | `"0xFF"` → `255` |
| `:rational` | Rational numbers | `"1/2"` → `Rational(1, 2)` |
| `:string` | String conversion | `123` → `"123"` |
| `:time` | Time objects | `"10:30:00"` → `Time` |
| `:virtual` | No conversion (default) | Input unchanged |

### Basic Usage

```ruby
class ProcessPaymentTask < CMDx::Task
  required :amount, type: :float
  required :user_id, type: :integer
  required :send_email, type: :boolean

  optional :metadata, type: :hash, default: {}
  optional :tags, type: :array, default: []

  def call
    # All parameters automatically coerced
    charge_amount = amount * 100  # Float math
    user = User.find(user_id)     # Integer lookup

    send_notification if send_email  # Boolean logic
  end
end

# Usage with string inputs
ProcessPaymentTask.call(
  amount: "99.99",           # → 99.99 (Float)
  user_id: "12345",          # → 12345 (Integer)
  send_email: "true",        # → true (Boolean)
  metadata: '{"source":"web"}',  # → {"source" => "web"} (Hash)
  tags: "[\"priority\"]"     # → ["priority"] (Array)
)
```

## Multiple Type Coercion

> [!TIP]
> Specify multiple types for fallback coercion. CMDx attempts each type in order until one succeeds.

```ruby
class ProcessOrderTask < CMDx::Task
  # Numeric: try precise float, fall back to integer
  required :total, type: [:float, :integer]

  # Data: try structured hash, fall back to raw string
  optional :notes, type: [:hash, :string]

  # Temporal: flexible date/time handling
  optional :due_date, type: [:datetime, :date, :string]

  def call
    case total
    when Float   then process_precise_amount(total)
    when Integer then process_rounded_amount(total)
    end

    case notes
    when Hash   then structured_notes = notes
    when String then fallback_notes = notes
    end
  end
end

# Different inputs produce different types
ProcessOrderTask.call(total: "99.99")  # → 99.99 (Float)
ProcessOrderTask.call(total: "100")    # → 100 (Integer)
```

## Advanced Examples

### Array and Hash Coercion

```ruby
class ProcessInventoryTask < CMDx::Task
  required :product_ids, type: :array
  required :config, type: :hash

  def call
    products = Product.where(id: product_ids)
    apply_configuration(config)
  end
end

# Multiple input formats supported
ProcessInventoryTask.call(
  product_ids: [1, 2, 3],              # Already array
  product_ids: "[1,2,3]",              # JSON string
  product_ids: "1",                    # Single value → ["1"]

  config: {key: "value"},              # Already hash
  config: '{"key":"value"}',           # JSON string
  config: [:key, "value"]              # Array pairs → Hash
)
```

### Boolean Patterns

```ruby
class UpdateUserSettingsTask < CMDx::Task
  required :notifications, type: :boolean
  required :active, type: :boolean

  def call
    user.update!(
      email_notifications: notifications,
      account_active: active
    )
  end
end

# Boolean coercion recognizes many patterns
UpdateUserSettingsTask.call(
  notifications: "true",    # → true
  notifications: "yes",     # → true
  notifications: "1",       # → true
  notifications: "on",      # → true

  active: "false",          # → false
  active: "no",             # → false
  active: "0",              # → false
  active: "off"             # → false
)
```

### Date and Time Handling

```ruby
class ScheduleEventTask < CMDx::Task
  required :event_date, type: :date
  required :start_time, type: :time

  # Custom formats for specific inputs
  optional :deadline, type: :date, format: "%m/%d/%Y"
  optional :meeting_time, type: :time, format: "%I:%M %p"

  def call
    Event.create!(
      scheduled_date: event_date,
      start_time: start_time,
      deadline: deadline,
      meeting_time: meeting_time
    )
  end
end

ScheduleEventTask.call(
  event_date: "2023-12-25",      # Standard ISO format
  start_time: "14:30:00",        # 24-hour format
  deadline: "12/31/2023",        # Custom MM/DD/YYYY format
  meeting_time: "2:30 PM"        # 12-hour with AM/PM
)
```

## Coercion with Nested Parameters

> [!IMPORTANT]
> Coercion applies at every level of nested parameter structures, enabling complex data transformation while maintaining type safety.

```ruby
class ProcessOrderTask < CMDx::Task
  required :order, type: :hash do
    required :id, type: :integer
    required :total, type: :float
    required :items, type: :array

    optional :customer, type: :hash do
      required :id, type: :integer
      required :active, type: :boolean
      optional :signup_date, type: :date
    end
  end

  def call
    order_id = order[:id]              # Integer (coerced)
    total_amount = order[:total]       # Float (coerced)

    if order[:customer]
      customer_id = order[:customer][:id]        # Integer (coerced)
      is_active = order[:customer][:active]      # Boolean (coerced)
      signup = order[:customer][:signup_date]    # Date (coerced)
    end
  end
end

# JSON input with automatic nested coercion
ProcessOrderTask.call(
  order: '{
    "id": "12345",
    "total": "299.99",
    "items": ["item1", "item2"],
    "customer": {
      "id": "67890",
      "active": "true",
      "signup_date": "2023-01-15"
    }
  }'
)
```

## Error Handling

> [!WARNING]
> Coercion failures provide detailed error information including parameter paths, attempted types, and specific failure reasons.

```ruby
class ProcessDataTask < CMDx::Task
  required :count, type: :integer
  required :amount, type: [:float, :big_decimal]
  required :active, type: :boolean

  def call
    # Task logic
  end
end

# Invalid inputs
result = ProcessDataTask.call(
  count: "not-a-number",
  amount: "invalid-float",
  active: "maybe"
)

result.failed?  # → true
result.metadata
# {
#   reason: "count could not coerce into an integer. amount could not coerce into one of: float, big_decimal. active could not coerce into a boolean.",
#   messages: {
#     count: ["could not coerce into an integer"],
#     amount: ["could not coerce into one of: float, big_decimal"],
#     active: ["could not coerce into a boolean"]
#   }
# }
```

### Common Error Scenarios

```ruby
# Invalid array JSON
ProcessDataTask.call(items: "[invalid json")
# → "items could not coerce into an array"

# Invalid date format
ProcessDataTask.call(start_date: "not-a-date")
# → "start_date could not coerce into a date"

# Multiple type failure
ProcessDataTask.call(value: "abc", type: [:integer, :float])
# → "value could not coerce into one of: integer, float"
```

## Custom Coercion Options

### Date/Time Formats

```ruby
class ImportDataTask < CMDx::Task
  # US date format
  required :birth_date, type: :date, format: "%m/%d/%Y"

  # European datetime
  required :timestamp, type: :datetime, format: "%d.%m.%Y %H:%M"

  # 12-hour time
  optional :appointment, type: :time, format: "%I:%M %p"

  def call
    # Dates parsed according to specified formats
  end
end
```

### BigDecimal Precision

```ruby
class CalculatePriceTask < CMDx::Task
  required :base_price, type: :big_decimal
  required :tax_rate, type: :big_decimal, precision: 8

  def call
    tax_amount = base_price * tax_rate  # High-precision calculation
  end
end
```

## Custom Coercions

> [!NOTE]
> Register custom coercions for domain-specific types not covered by built-in coercions.

```ruby
# Custom coercion for currency handling
module CurrencyCoercion
  module_function

  def call(value, options = {})
    return value if value.is_a?(BigDecimal)

    # Remove currency symbols and formatting
    clean_value = value.to_s.gsub(/[$,£€¥]/, '')
    BigDecimal(clean_value)
  rescue ArgumentError
    raise CMDx::Coercion::Error, "Invalid currency format: #{value}"
  end
end

# URL slug coercion
SlugCoercion = proc do |value|
  value.to_s.downcase
       .gsub(/[^a-z0-9\s-]/, '')
       .gsub(/\s+/, '-')
       .gsub(/-+/, '-')
       .strip('-')
end

# Register coercions globally
CMDx.configure do |config|
  config.coercions.register(:currency, CurrencyCoercion)
  config.coercions.register(:slug, SlugCoercion)
end

# Use in tasks
class ProcessProductTask < CMDx::Task
  required :price, type: :currency
  required :url_slug, type: :slug

  def call
    price    # → BigDecimal from "$99.99"
    url_slug # → "my-product-name" from "My Product Name!"
  end
end

ProcessProductTask.call(
  price: "$149.99",
  url_slug: "My Amazing Product!"
)
```

> [!TIP]
> Custom coercions should be idempotent and handle edge cases gracefully. Include proper error handling for invalid inputs.

---

- **Prev:** [Parameters - Namespacing](namespacing.md)
- **Next:** [Parameters - Validations](validations.md)
