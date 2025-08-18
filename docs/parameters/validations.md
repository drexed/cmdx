# Parameters - Validations

Parameter validations ensure data integrity by applying constraints to task inputs. All validators integrate with CMDx's error handling system and support internationalization for consistent error messaging across different locales.

## Table of Contents

- [TLDR](#tldr)
- [Common Options](#common-options)
- [Presence](#presence)
- [Format](#format)
- [Inclusion](#inclusion)
- [Exclusion](#exclusion)
- [Length](#length)
- [Numeric](#numeric)
- [Error Handling](#error-handling)
- [Conditional Validation](#conditional-validation)

## TLDR

```ruby
# Basic validation
required :email, presence: true, format: { with: /@/ }
required :status, inclusion: { in: %w[pending active] }
required :password, length: { min: 8 }

# Conditional validation
optional :phone, presence: { if: :phone_required? }
required :age, numeric: { min: 18, unless: :minor_allowed? }

# Custom messages
required :username, exclusion: { in: %w[admin root], message: "reserved name" }
```

## Common Options

> [!NOTE]
> Validators on `optional` parameters only execute when arguments are provided.

All validators support these common options:

| Option | Description |
|--------|-------------|
| `:allow_nil` | Skip validation when value is `nil` |
| `:if` | Method, proc, or string determining when to validate |
| `:unless` | Method, proc, or string determining when to skip validation |
| `:message` | Custom error message for validation failures |

## Presence

Validates that parameter values are not empty using intelligent type checking:

- **Strings**: Must contain non-whitespace characters
- **Collections**: Must not be empty (arrays, hashes, sets)
- **Other objects**: Must not be `nil`

> [!TIP]
> For boolean fields accepting `true` and `false`, use `inclusion: { in: [true, false] }` instead of presence validation.

```ruby
class CreateUserTask < CMDx::Task
  required :email, presence: true
  required :name, presence: { message: "cannot be blank" }
  required :active, inclusion: { in: [true, false] }

  def call
    User.create!(email: email, name: name, active: active)
  end
end

# Valid inputs
CreateUserTask.call(email: "user@example.com", name: "John", active: true)

# Invalid inputs
CreateUserTask.call(email: "", name: "   ", active: nil)
# → ValidationError: "email can't be blank. name cannot be blank. active must be one of: true, false"
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
    if: :secure_password_required?
  }

  def call
    create_user_account
  end

  private

  def secure_password_required?
    context.security_policy.enforce_strong_passwords?
  end
end
```

**Options:**

| Option | Description |
|--------|-------------|
| `:with` | Regular expression that value must match |
| `:without` | Regular expression that value must not match |

## Inclusion

> [!IMPORTANT]
> Validates that parameter values are within a specific set of allowed values (array, range, or other enumerable).

```ruby
class UpdateOrderTask < CMDx::Task
  required :status, inclusion: { in: %w[pending processing shipped delivered] }
  required :priority, inclusion: { in: 1..5 }

  optional :shipping_method, inclusion: {
    in: %w[standard express overnight],
    unless: :digital_product?
  }

  def call
    update_order_attributes
  end

  private

  def digital_product?
    context.order.items.all?(&:digital?)
  end
end
```

**Options:**

| Option | Description |
|--------|-------------|
| `:in` | Enumerable of allowed values |
| `:within` | Alias for `:in` |

**Custom Error Messages:**

| Option | Description |
|--------|-------------|
| `:of_message` | Error for array validation (default: "must be one of: %{values}") |
| `:in_message` | Error for range validation (default: "must be within %{min} and %{max}") |
| `:within_message` | Alias for `:in_message` |

## Exclusion

Validates that parameter values are not within a specific set of forbidden values.

```ruby
class ProcessPaymentTask < CMDx::Task
  required :payment_method, exclusion: { in: %w[cash check] }
  required :amount, exclusion: { in: 0.0..0.99, in_message: "must be at least $1.00" }

  optional :promo_code, exclusion: {
    in: %w[EXPIRED INVALID],
    of_message: "is not valid"
  }

  def call
    charge_payment_method
  end
end

# Valid usage
ProcessPaymentTask.call(
  payment_method: "credit_card",
  amount: 29.99,
  promo_code: "SAVE20"
)
```

**Options:**

| Option | Description |
|--------|-------------|
| `:in` | Enumerable of forbidden values |
| `:within` | Alias for `:in` |

**Custom Error Messages:**

| Option | Description |
|--------|-------------|
| `:of_message` | Error for array validation (default: "must not be one of: %{values}") |
| `:in_message` | Error for range validation (default: "must not be within %{min} and %{max}") |
| `:within_message` | Alias for `:in_message` |

## Length

Validates parameter length for any object responding to `#size` or `#length`. Only one constraint option can be used at a time, except `:min` and `:max` which can be combined.

```ruby
class CreatePostTask < CMDx::Task
  required :title, length: { within: 5..100 }
  required :content, length: { min: 50 }
  required :slug, length: { min: 3, max: 50 }

  optional :summary, length: { max: 200, allow_nil: true }
  optional :category_code, length: { is: 3 }

  def call
    Post.create!(title: title, content: content, slug: slug)
  end
end
```

**Constraint Options:**

| Option | Description |
|--------|-------------|
| `:within` / `:in` | Range specifying min and max length |
| `:not_within` / `:not_in` | Range specifying forbidden length range |
| `:min` | Minimum length required |
| `:max` | Maximum length allowed |
| `:is` | Exact length required |
| `:is_not` | Length that is forbidden |

**Error Messages:**

| Option | Description |
|--------|-------------|
| `:within_message` | "length must be within %{min} and %{max}" |
| `:not_within_message` | "length must not be within %{min} and %{max}" |
| `:min_message` | "length must be at least %{min}" |
| `:max_message` | "length must be at most %{max}" |
| `:is_message` | "length must be %{is}" |
| `:is_not_message` | "length must not be %{is_not}" |

## Numeric

Validates numeric values against constraints. Works with any numeric type including integers, floats, and decimals.

```ruby
class ProcessOrderTask < CMDx::Task
  required :quantity, numeric: { within: 1..100 }
  required :price, numeric: { min: 0.01 }
  required :tax_rate, numeric: { min: 0, max: 0.25 }

  optional :discount, numeric: { max: 50, allow_nil: true }
  optional :api_version, numeric: { is: 2 }

  def call
    calculate_order_total
  end
end

# Error example
ProcessOrderTask.call(
  quantity: 0,      # Below minimum
  price: -5.00,     # Below minimum
  tax_rate: 0.30    # Above maximum
)
# → ValidationError: "quantity must be within 1 and 100. price must be at least 0.01. tax_rate must be at most 0.25"
```

**Constraint Options:**

| Option | Description |
|--------|-------------|
| `:within` / `:in` | Range specifying min and max value |
| `:not_within` / `:not_in` | Range specifying forbidden value range |
| `:min` | Minimum value required |
| `:max` | Maximum value allowed |
| `:is` | Exact value required |
| `:is_not` | Value that is forbidden |

## Error Handling

> [!WARNING]
> Validation failures cause tasks to enter a failed state with detailed error information including parameter paths and specific violation messages.

```ruby
class CreateUserTask < CMDx::Task
  required :email, format: { with: /@/, message: "must be valid" }
  required :username, presence: true, length: { min: 3 }
  required :age, numeric: { min: 13, max: 120 }

  def call
    # Process user
  end
end

result = CreateUserTask.call(
  email: "invalid-email",
  username: "",
  age: 5
)

result.state    # → "interrupted"
result.status   # → "failed"
result.failed?  # → true

# Detailed error information
result.metadata
# {
#   email must be valid. username can't be blank. username length must be at least 3. age must be at least 13.",
#   messages: {
#     email: ["must be valid"],
#     username: ["can't be blank", "length must be at least 3"],
#     age: ["must be at least 13"]
#   }
# }

# Access specific parameter errors
result.metadata[:messages][:email]    # → ["must be valid"]
result.metadata[:messages][:username] # → ["can't be blank", "length must be at least 3"]
```

### Nested Parameter Validation

```ruby
class ProcessOrderTask < CMDx::Task
  required :order, type: :hash do
    required :customer_email, format: { with: /@/ }
    required :items, type: :array, length: { min: 1 }

    optional :shipping, type: :hash do
      required :method, inclusion: { in: %w[standard express] }
      required :address, presence: true
    end
  end

  def call
    # Process validated order
  end
end

# Nested validation errors
result = ProcessOrderTask.call(
  order: {
    customer_email: "invalid",
    items: [],
    shipping: {
      method: "invalid",
      address: ""
    }
  }
)

result.metadata[:messages]
# {
#   "order.customer_email" => ["is invalid"],
#   "order.items" => ["length must be at least 1"],
#   "order.shipping.method" => ["must be one of: standard, express"],
#   "order.shipping.address" => ["can't be blank"]
# }
```

## Conditional Validation

> [!TIP]
> Use `:if` and `:unless` options to apply validations conditionally based on runtime context or other parameter values.

```ruby
class UserRegistrationTask < CMDx::Task
  required :email, presence: true, format: { with: /@/ }
  required :user_type, inclusion: { in: %w[individual business] }

  # Conditional validations based on user type
  optional :company_name, presence: { if: :business_user? }
  optional :tax_id, format: { with: /\A\d{2}-\d{7}\z/, if: :business_user? }

  # Conditional validation with procs
  optional :phone, presence: {
    if: proc { |task| task.context.require_phone_verification? }
  }

  # Multiple conditions
  optional :parent_email, presence: {
    if: :minor_user?,
    format: { with: /@/, unless: :parent_present? }
  }

  def call
    create_user_account
  end

  private

  def business_user?
    user_type == "business"
  end

  def minor_user?
    context.user_age < 18
  end

  def parent_present?
    context.parent_guardian_present?
  end
end
```

---

- **Prev:** [Parameters - Coercions](coercions.md)
- **Next:** [Parameters - Defaults](defaults.md)
