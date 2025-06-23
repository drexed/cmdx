# Parameters - Validations

Parameter values can be validated using built-in validators or custom validation logic. All validators support internationalization (i18n) and integrate seamlessly with CMDx's error handling system.

**Built-in validators:** [Presence](#presence), [Format](#format), [Exclusion](#exclusion), [Inclusion](#inclusion), [Length](#length), [Numeric](#numeric), [Custom](#custom)

## Common Options

All validators support the following common options:

| Option       | Description |
| ------------ | ----------- |
| `:allow_nil` | Skip validation if the parameter value is `nil` |
| `:if`        | Specifies a callable method, proc or string to determine if the validation should occur |
| `:unless`    | Specifies a callable method, proc, or string to determine if the validation should not occur |
| `:message`   | The error message to use for a violation. Fallback for any error key below that's not provided |

> [!NOTE]
> Validators on `optional` parameters will only be executed if they are supplied as call arguments.

## Presence

Validates that the specified parameter value is not empty. Uses intelligent presence checking based on value type:
- **Strings**: Must contain non-whitespace characters (not just spaces, tabs, or newlines)
- **Collections**: Must not be empty (arrays, hashes, etc.)
- **Other objects**: Must not be `nil`

For boolean fields where valid values are `true` and `false`, use `inclusion: { in: [true, false] }` instead of presence validation.

```ruby
class UpdateUserDetailsTask < CMDx::Task
  # Basic presence validation
  required :username, presence: true

  # With custom error message
  optional :email, presence: { message: "must not be empty" }

  # Boolean field - use inclusion instead
  required :active, inclusion: { in: [true, false] }

  def call
    # Do work...
  end
end
```

## Format

Validates whether the parameter value matches regular expression patterns. Supports positive matching (`with`), negative matching (`without`), or both combined for complex validation.

```ruby
class UpdateUserDetailsTask < CMDx::Task
  # Positive pattern - must match
  required :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }

  # Negative pattern - must not match
  optional :username, format: { without: /\A(admin|root|system)\z/i }

  # Combined patterns with conditional validation
  optional :password, format: {
    with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,
    without: /password|123456/i,
    if: proc { Current.account.requires_strong_password? }
  }

  def call
    # Do work...
  end
end
```

**Constraint options:**

| Option     | Description |
| ---------- | ----------- |
| `:with`    | Regular expression that the parameter value must match for successful validation |
| `:without` | Regular expression that the parameter value must not match for successful validation |

## Exclusion

Validates that the parameter value is not in a particular enumerable object (array, range, etc.).

```ruby
class DetermineBoxSizeTask < CMDx::Task
  # Array exclusion
  required :width, exclusion: { in: [12, 24, 36] }

  # Range exclusion with allow_nil
  optional :length, exclusion: { in: 12..36, allow_nil: true }

  # Using :within alias
  optional :height, exclusion: { within: 0..5 }

  def call
    # Do work...
  end
end
```

**Constraint options:**

| Option       | Description |
| ------------ | ----------- |
| `:in`        | An enumerable object of unavailable items such as an array or range |
| `:within`    | A synonym (or alias) for `:in` |

**Other options:**

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | The error message if the parameter value is in array. (default: "must not be one of: %{values}") |
| `:in_message`     | The error message if the parameter value is in range. (default: "must not be within %{min} and %{max}") |
| `:within_message` | A synonym (or alias) for `:in_message` |

## Inclusion

Validates that the parameter value is in a particular enumerable object (array, range, etc.).

```ruby
class DetermineBoxSizeTask < CMDx::Task
  # Array inclusion
  required :width, inclusion: { in: [12, 24, 36] }

  # Range inclusion with conditional validation
  optional :length, inclusion: { in: 12..36, unless: :skip_length_check? }

  # Using :within alias
  optional :priority, inclusion: { within: %w[low medium high] }

  def call
    # Do work...
  end

  private

  def skip_length_check?
    false
  end
end
```

**Constraint options:**

| Option       | Description |
| ------------ | ----------- |
| `:in`        | An enumerable object of available items such as an array or range |
| `:within`    | A synonym (or alias) for `:in` |

**Other options:**

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | The error message if the parameter value is not in array. (default: "must be one of: %{values}") |
| `:in_message`     | The error message if the parameter value is not in range. (default: "must be within %{min} and %{max}") |
| `:within_message` | A synonym (or alias) for `:in_message` |

## Length

Validates that the parameter value matches the length restrictions. Works with any object that responds to `#size` or `#length` (strings, arrays, hashes, etc.). Only one constraint option can be used at a time, except for `:min` and `:max` which can be combined.

```ruby
class UpdateUserDetailsTask < CMDx::Task
  # Range validation
  required :username, length: { within: 3..20 }
  required :password, length: { not_within: 1..7 }

  # Boundary validation
  optional :first_name, length: { min: 2 }
  optional :middle_name, length: { max: 48 }
  optional :last_name, length: { min: 2, max: 48 }  # Combined min/max

  # Exact length validation
  required :country_code, length: { is: 2 }
  required :legacy_id, length: { is_not: 0 }

  # Using aliases
  optional :bio, length: { in: 10..500 }  # Alias for :within

  def call
    # Do work...
  end
end
```

**Constraint options:**

| Option        | Description |
| ------------- | ----------- |
| `:within`     | A range specifying the minimum and maximum size of the parameter value |
| `:not_within` | A range specifying the minimum and maximum size of the parameter value it's not to be |
| `:in`         | A synonym (or alias) for `:within` |
| `:not_in`     | A synonym (or alias) for `:not_within` |
| `:min`        | The minimum size of the parameter value |
| `:max`        | The maximum size of the parameter value |
| `:is`         | The exact size of the parameter value |
| `:is_not`     | The exact size of the parameter value it's not to be |

**Other options:**

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | The error message if the parameter value is not within the value range. (default: "length must be within %{min} and %{max}") |
| `:not_within_message` | The error message if the parameter value is within the value range. (default: "length must not be within %{min} and %{max}") |
| `:in_message`         | A synonym (or alias) for `:within_message` |
| `:not_in_message`     | A synonym (or alias) for `:not_within_message` |
| `:min_message`        | The error message if the parameter value is below the min value. (default: "length must be at least %{min}") |
| `:max_message`        | The error message if the parameter value is above the max value. (default: "length must be at most %{max}") |
| `:is_message`         | The error message if the parameter value is not the exact value. (default: "length must be %{is}") |
| `:is_not_message`     | The error message if the parameter value is the exact value. (default: "length must not be %{is_not}") |

## Numeric

Validates that the parameter value matches numeric restrictions. Works with any numeric type (integers, floats, decimals, etc.). Only one constraint option can be used at a time, except for `:min` and `:max` which can be combined.

```ruby
class ProcessOrderTask < CMDx::Task
  # Range validation
  required :quantity, numeric: { within: 1..100 }
  required :discount_percent, numeric: { not_within: 90..100 }  # Avoid excessive discounts

  # Boundary validation
  optional :age, numeric: { min: 18 }
  optional :score, numeric: { max: 100 }
  optional :rating, numeric: { min: 1, max: 5 }  # Combined min/max

  # Exact value validation
  required :api_version, numeric: { is: 2 }
  required :legacy_flag, numeric: { is_not: 0 }

  # Using aliases
  optional :price, numeric: { in: 0.01..999.99 }  # Alias for :within

  def call
    # Do work...
  end
end
```

**Constraint options:**

| Option        | Description |
| ------------- | ----------- |
| `:within`     | A range specifying the minimum and maximum value of the parameter |
| `:not_within` | A range specifying the minimum and maximum value of the parameter it's not to be |
| `:in`         | A synonym (or alias) for `:within` |
| `:not_in`     | A synonym (or alias) for `:not_within` |
| `:min`        | The minimum value of the parameter |
| `:max`        | The maximum value of the parameter |
| `:is`         | The exact value of the parameter |
| `:is_not`     | The exact value of the parameter it's not to be |

**Other options:**

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | The error message if the parameter value is not within the value range. (default: "must be within %{min} and %{max}") |
| `:not_within_message` | The error message if the parameter value is within the value range. (default: "must not be within %{min} and %{max}") |
| `:in_message`         | A synonym (or alias) for `:within_message` |
| `:not_in_message`     | A synonym (or alias) for `:not_within_message` |
| `:min_message`        | The error message if the parameter value is below the min value. (default: "must be at least %{min}") |
| `:max_message`        | The error message if the parameter value is above the max value. (default: "must be at most %{max}") |
| `:is_message`         | The error message if the parameter value is not the exact value. (default: "must be %{is}") |
| `:is_not_message`     | The error message if the parameter value is the exact value. (default: "must not be %{is_not}") |

## Custom

Validates the parameter value using custom validation logic. Accepts any callable object (class, proc, lambda) that implements a `call` method returning a truthy value for successful validation.

```ruby
class EmailDomainValidator
  def self.call(value, options)
    allowed_domains = options.dig(:custom, :domains) || ['example.com']
    domain = value.split('@').last
    allowed_domains.include?(domain)
  end
end

class AgeValidator
  def self.call(value, options)
    min_age = options.dig(:custom, :min_age) || 18
    max_age = options.dig(:custom, :max_age) || 120
    value.between?(min_age, max_age)
  end
end

class ProcessUserTask < CMDx::Task
  # Basic custom validator
  required :email, custom: { validator: EmailDomainValidator }

  # Custom validator with options
  optional :work_email, custom: {
    validator: EmailDomainValidator,
    domains: ['company.com', 'partner.org'],
    message: "must be from an approved domain"
  }

  # Complex business logic validator
  optional :age, custom: {
    validator: AgeValidator,
    min_age: 21,
    max_age: 65,
    message: "must be between %{min_age} and %{max_age}"
  }

  # Proc-based validator
  required :discount, custom: {
    validator: ->(value, options) { value <= 50 },
    message: "cannot exceed 50%"
  }

  def call
    # Do work...
  end
end
```

**Constraint options:**

| Option       | Description |
| ------------ | ----------- |
| `:validator` | Callable object (class, proc, lambda) that returns true/false. Receives value and options as parameters |

## Validation Results

When validation fails, the task enters a failed state with detailed error information:

```ruby
class ProcessUserTask < CMDx::Task
  required :email, format: { with: /@/, message: "format is not valid" }
  required :username, presence: { message: "cannot be empty" }
end

result = ProcessUserTask.call(email: "invalid", username: "")

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "email format is not valid. username cannot be empty."
result.metadata #=> {
             #=>   reason: "email format is not valid. username cannot be empty.",
             #=>   messages: {
             #=>     email: ["format is not valid"],
             #=>     username: ["cannot be empty"]
             #=>   }
             #=> }

# Accessing individual error messages
result.metadata[:messages][:email]    #=> ["format is not valid"]
result.metadata[:messages][:username] #=> ["cannot be empty"]
```

## Internationalization (i18n)

All validators support internationalization through Rails i18n. You can customize error messages in your locale files:

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

- **Prev:** [Parameters - Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
- **Next:** [Parameters - Defaults](https://github.com/drexed/cmdx/blob/main/docs/parameters/defaults.md)
