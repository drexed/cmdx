# Parameters - Validations

Parameter values can be validated using built-in validators or custom validation logic. All validators support internationalization (i18n) and integrate seamlessly with CMDx's error handling system.

## Table of Contents

- [TLDR](#tldr)
- [Common Options](#common-options)
- [Presence](#presence)
- [Format](#format)
- [Exclusion](#exclusion)
- [Inclusion](#inclusion)
- [Length](#length)
- [Numeric](#numeric)
- [Custom](#custom)
- [Validation Results](#validation-results)
- [Internationalization (i18n)](#internationalization-i18n)

## TLDR

- **Built-in validators** - `presence`, `format`, `inclusion`, `exclusion`, `length`, `numeric`
- **Common options** - All support `:allow_nil`, `:if`, `:unless`, `:message`
- **Usage** - Add to parameter definitions: `required :email, presence: true, format: { with: /@/ }`
- **Conditional** - Use `:if` and `:unless` for conditional validation
- **Custom validators** - Use `custom: { validator: CustomValidator }` for complex logic

## Common Options

All validators support these common options:

| Option       | Description |
| ------------ | ----------- |
| `:allow_nil` | Skip validation if the parameter value is `nil` |
| `:if`        | Callable method, proc or string to determine if validation should occur |
| `:unless`    | Callable method, proc, or string to determine if validation should not occur |
| `:message`   | Error message for violations. Fallback for specific error keys not provided |

> [!NOTE]
> Validators on `optional` parameters only execute when arguments are supplied.

## Presence

Validates that parameter values are not empty using intelligent type checking:
- **Strings**: Must contain non-whitespace characters
- **Collections**: Must not be empty (arrays, hashes, etc.)
- **Other objects**: Must not be `nil`

> [!TIP]
> For boolean fields where valid values are `true` and `false`, use `inclusion: { in: [true, false] }` instead of presence validation.

```ruby
class CreateUserTask < CMDx::Task
  required :email, presence: true
  optional :phone, presence: { message: "cannot be blank" }
  required :active, inclusion: { in: [true, false] }

  def call
    User.create!(email: email, phone: phone, active: active)
  end
end
```

## Format

Validates parameter values against regular expression patterns. Supports positive matching (`with`), negative matching (`without`), or both.

```ruby
class RegisterUserTask < CMDx::Task
  required :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
  required :username, format: { without: /\A(admin|root|system)\z/i }
  optional :password, format: {
    with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,
    without: /password|123456/i,
    if: :strong_password_required?
  }

  def call
    create_user_account
  end

  private

  def strong_password_required?
    context.account.security_policy.strong_passwords?
  end
end
```

**Options:**

| Option     | Description |
| ---------- | ----------- |
| `:with`    | Regular expression that value must match |
| `:without` | Regular expression that value must not match |

## Exclusion

Validates that parameter values are not in a specific enumerable (array, range, etc.).

```ruby
class ProcessPaymentTask < CMDx::Task
  required :payment_method, exclusion: { in: %w[cash check] }
  required :amount, exclusion: { in: 0.0..0.99, in_message: "must be at least $1.00" }
  optional :discount_percent, exclusion: { in: 90..100 }

  def call
    charge_payment
  end
end
```

**Options:**

| Option       | Description |
| ------------ | ----------- |
| `:in`        | Enumerable of forbidden values |
| `:within`    | Alias for `:in` |

**Error Messages:**

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | Error when value is in array (default: "must not be one of: %{values}") |
| `:in_message`     | Error when value is in range (default: "must not be within %{min} and %{max}") |
| `:within_message` | Alias for `:in_message` |

## Inclusion

Validates that parameter values are in a specific enumerable (array, range, etc.).

```ruby
class UpdateOrderTask < CMDx::Task
  required :status, inclusion: { in: %w[pending processing shipped delivered] }
  required :priority, inclusion: { in: 1..5 }
  optional :shipping_method, inclusion: {
    in: %w[standard express overnight],
    unless: :digital_order?
  }

  def call
    update_order_status
  end

  private

  def digital_order?
    context.order.digital_items_only?
  end
end
```

**Options:**

| Option       | Description |
| ------------ | ----------- |
| `:in`        | Enumerable of allowed values |
| `:within`    | Alias for `:in` |

**Error Messages:**

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | Error when value not in array (default: "must be one of: %{values}") |
| `:in_message`     | Error when value not in range (default: "must be within %{min} and %{max}") |
| `:within_message` | Alias for `:in_message` |

## Length

Validates parameter length/size. Works with any object responding to `#size` or `#length`. Only one constraint option can be used at a time, except `:min` and `:max` which can be combined.

```ruby
class CreatePostTask < CMDx::Task
  required :title, length: { within: 5..100 }
  required :body, length: { min: 20 }
  optional :summary, length: { max: 200 }
  required :slug, length: { min: 3, max: 50 }
  required :category_code, length: { is: 3 }

  def call
    create_blog_post
  end
end
```

**Options:**

| Option        | Description |
| ------------- | ----------- |
| `:within`     | Range specifying min and max size |
| `:not_within` | Range specifying forbidden size range |
| `:in`         | Alias for `:within` |
| `:not_in`     | Alias for `:not_within` |
| `:min`        | Minimum size required |
| `:max`        | Maximum size allowed |
| `:is`         | Exact size required |
| `:is_not`     | Size that is forbidden |

**Error Messages:**

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | "length must be within %{min} and %{max}" |
| `:not_within_message` | "length must not be within %{min} and %{max}" |
| `:min_message`        | "length must be at least %{min}" |
| `:max_message`        | "length must be at most %{max}" |
| `:is_message`         | "length must be %{is}" |
| `:is_not_message`     | "length must not be %{is_not}" |

## Numeric

Validates numeric values against constraints. Works with any numeric type. Only one constraint option can be used at a time, except `:min` and `:max` which can be combined.

```ruby
class ProcessOrderTask < CMDx::Task
  required :quantity, numeric: { within: 1..100 }
  required :price, numeric: { min: 0.01 }
  optional :discount_percent, numeric: { max: 50 }
  required :tax_rate, numeric: { min: 0, max: 0.15 }
  required :api_version, numeric: { is: 2 }

  def call
    calculate_order_total
  end
end
```

**Options:**

| Option        | Description |
| ------------- | ----------- |
| `:within`     | Range specifying min and max value |
| `:not_within` | Range specifying forbidden value range |
| `:in`         | Alias for `:within` |
| `:not_in`     | Alias for `:not_within` |
| `:min`        | Minimum value required |
| `:max`        | Maximum value allowed |
| `:is`         | Exact value required |
| `:is_not`     | Value that is forbidden |

**Error Messages:**

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | "must be within %{min} and %{max}" |
| `:not_within_message` | "must not be within %{min} and %{max}" |
| `:min_message`        | "must be at least %{min}" |
| `:max_message`        | "must be at most %{max}" |
| `:is_message`         | "must be %{is}" |
| `:is_not_message`     | "must not be %{is_not}" |

## Custom

Validates using custom logic. Accepts any callable object (class, proc, lambda) implementing a `call` method that returns truthy for valid values.

```ruby
class EmailDomainValidator
  def self.call(value, options)
    allowed_domains = options.dig(:custom, :allowed_domains) || ['example.com']
    domain = value.split('@').last
    allowed_domains.include?(domain)
  end
end

class CreateAccountTask < CMDx::Task
  required :work_email, custom: {
    validator: EmailDomainValidator,
    allowed_domains: ['company.com', 'partner.org'],
    message: "must be from an approved domain"
  }

  required :age, custom: {
    validator: ->(value, options) { value.between?(18, 120) },
    message: "must be a valid age"
  }

  def call
    create_user_account
  end
end
```

**Options:**

| Option       | Description |
| ------------ | ----------- |
| `:validator` | Callable object returning true/false. Receives value and options as parameters |

## Validation Results

When validation fails, tasks enter a failed state with detailed error information:

```ruby
class CreateUserTask < CMDx::Task
  required :email, format: { with: /@/, message: "format is invalid" }
  required :username, presence: { message: "cannot be empty" }
end

result = CreateUserTask.call(email: "invalid", username: "")

result.state    #=> "interrupted"
result.status   #=> "failed"
result.metadata #=> {
                #=>   reason: "email format is invalid. username cannot be empty.",
                #=>   messages: {
                #=>     email: ["format is invalid"],
                #=>     username: ["cannot be empty"]
                #=>   }
                #=> }

# Accessing individual error messages
result.metadata[:messages][:email]    #=> ["format is invalid"]
result.metadata[:messages][:username] #=> ["cannot be empty"]
```

## Internationalization (i18n)

All validators support internationalization through Rails i18n. Customize error messages in your locale files:

```yaml
# config/locales/en.yml
en:
  cmdx:
    validators:
      presence: "is required"
      format: "has invalid format"
      inclusion:
        of: "must be one of: %{values}"
        in: "must be within %{min} and %{max}"
      exclusion:
        of: "must not be one of: %{values}"
        in: "must not be within %{min} and %{max}"
      length:
        within: "must be between %{min} and %{max} characters"
        min: "must be at least %{min} characters"
        max: "must be at most %{max} characters"
      numeric:
        within: "must be between %{min} and %{max}"
        min: "must be at least %{min}"
        max: "must be at most %{max}"
      custom: "is invalid"
```

---

- **Prev:** [Parameters - Coercions](coercions.md)
- **Next:** [Parameters - Defaults](defaults.md)
