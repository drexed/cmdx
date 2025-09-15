# Attributes - Validations

Attribute validations ensure task arguments meet specified requirements before execution begins. Validations run after coercions and provide declarative rules for data integrity, supporting both built-in validators and custom validation logic.

Check out the [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#validations) docs for global configuration.

## Table of Contents

- [Usage](#usage)
- [Built-in Validators](#built-in-validators)
  - [Common Options](#common-options)
  - [Exclusion](#exclusion)
  - [Format](#format)
  - [Inclusion](#inclusion)
  - [Length](#length)
  - [Numeric](#numeric)
  - [Presence](#presence)
- [Declarations](#declarations)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Removals](#removals)
- [Error Handling](#error-handling)

## Usage

Define validation rules on attributes to enforce data requirements:

```ruby
class ProcessSubscription < CMDx::Task
  # Required field with presence validation
  attribute :user_id, presence: true

  # String with length constraints
  attribute :preferences, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  attribute :tier_level, inclusion: { in: 1..5 }

  # Format validation for email
  attribute :contact_email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    user_id       #=> "98765"
    preferences   #=> "Send weekly digest emails"
    tier_level    #=> 3
    contact_email #=> "user@company.com"
  end
end

ProcessSubscription.execute(
  user_id: "98765",
  preferences: "Send weekly digest emails",
  tier_level: 3,
  contact_email: "user@company.com"
)
```

> [!TIP]
> Validations run after coercions, so you can validate the final coerced values rather than raw input.

## Built-in Validators

### Common Options

This list of options is available to all validators:

| Option | Description |
|--------|-------------|
| `:allow_nil` | Skip validation when value is `nil` |
| `:if` | Symbol, proc, lambda, or callable determining when to validate |
| `:unless` | Symbol, proc, lambda, or callable determining when to skip validation |
| `:message` | Custom error message for validation failures |

### Exclusion

```ruby
class ProcessProduct < CMDx::Task
  attribute :status, exclusion: { in: %w[recalled archived] }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:in` | The collection of forbidden values or range |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for discrete value exclusions |
| `:in_message` | Custom message for range-based exclusions |
| `:within_message` | Alias for :in_message option |

### Format

```ruby
class ProcessProduct < CMDx::Task
  attribute :sku, format: /\A[A-Z]{3}-[0-9]{4}\z/

  attribute :sku, format: { with: /\A[A-Z]{3}-[0-9]{4}\z/ }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `regexp` | Alias for :with option |
| `:with` | Regex pattern that the value must match |
| `:without` | Regex pattern that the value must not match |

### Inclusion

```ruby
class ProcessProduct < CMDx::Task
  attribute :availability, inclusion: { in: %w[available limited] }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:in` | The collection of allowed values or range |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for discrete value inclusions |
| `:in_message` | Custom message for range-based inclusions |
| `:within_message` | Alias for :in_message option |

### Length

```ruby
class CreateBlogPost < CMDx::Task
  attribute :title, length: { within: 5..100 }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the length must fall within (inclusive) |
| `:not_within` | Range that the length must not fall within |
| `:in` | Alias for :within |
| `:not_in` | Range that the length must not fall within |
| `:min` | Minimum allowed length |
| `:max` | Maximum allowed length |
| `:is` | Exact required length |
| `:is_not` | Length that is not allowed |
| `:within_message` | Custom message for within/range validations |
| `:in_message` | Custom message for :in validation |
| `:not_within_message` | Custom message for not_within validation |
| `:not_in_message` | Custom message for not_in validation |
| `:min_message` | Custom message for minimum length validation |
| `:max_message` | Custom message for maximum length validation |
| `:is_message` | Custom message for exact length validation |
| `:is_not_message` | Custom message for is_not validation |

### Numeric

```ruby
class CreateBlogPost < CMDx::Task
  attribute :word_count, numeric: { min: 100 }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the value must fall within (inclusive) |
| `:not_within` | Range that the value must not fall within |
| `:in` | Alias for :within option |
| `:not_in` | Alias for :not_within option |
| `:min` | Minimum allowed value (inclusive, >=) |
| `:max` | Maximum allowed value (inclusive, <=) |
| `:is` | Exact value that must match |
| `:is_not` | Value that must not match |
| `:within_message` | Custom message for range validations |
| `:not_within_message` | Custom message for exclusion validations |
| `:min_message` | Custom message for minimum validation |
| `:max_message` | Custom message for maximum validation |
| `:is_message` | Custom message for exact match validation |
| `:is_not_message` | Custom message for exclusion validation |

### Presence

```ruby
class CreateBlogPost < CMDx::Task
  attribute :content, presence: true

  attribute :content, presence: { message: "cannot be blank" }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `true` | Ensures value is not nil, empty string, or whitespace |

## Declarations

> [!IMPORTANT]
> Custom validators must raise a `CMDx::ValidationError` and its message is used as part of the fault reason and metadata.

### Proc or Lambda

Use anonymous functions for simple validation logic:

```ruby
class SetupApplication < CMDx::Task
  # Proc
  register :validator, :api_key, proc do |value, options = {}|
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  end

  # Lambda
  register :validator, :api_key, ->(value, options = {}) {
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  }
end
```

### Class or Module

Register custom validation logic for specialized requirements:

```ruby
class ApiKeyValidator
  def self.call(value, options = {})
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  end
end

class SetupApplication < CMDx::Task
  register :validator, :api_key, ApiKeyValidator

  attribute :access_key, api_key: true
end
```

## Removals

Remove custom validators when no longer needed:

> [!WARNING]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## Error Handling

Validation failures provide detailed error information including attribute paths, validation rules, and specific failure reasons:

```ruby
class CreateProject < CMDx::Task
  attribute :project_name, presence: true, length: { minimum: 3, maximum: 50 }
  attribute :budget, numeric: { greater_than: 1000, less_than: 1000000 }
  attribute :priority, inclusion: { in: [:low, :medium, :high] }
  attribute :contact_email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    # Your logic here...
  end
end

result = CreateProject.execute(
  project_name: "AB",           # Too short
  budget: 500,                  # Too low
  priority: :urgent,            # Not in allowed list
  contact_email: "invalid-email"    # Invalid format
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "project_name is too short (minimum is 3 characters). budget must be greater than 1000. priority is not included in the list. contact_email is invalid.",
                #       messages: {
                #         project_name: ["is too short (minimum is 3 characters)"],
                #         budget: ["must be greater than 1000"],
                #         priority: ["is not included in the list"],
                #         contact_email: ["is invalid"]
                #       }
                #     }
                #   }
```

---

- **Prev:** [Attributes - Coercions](coercions.md)
- **Next:** [Attributes - Defaults](defaults.md)
