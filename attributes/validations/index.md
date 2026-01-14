# Attributes - Validations

Ensure inputs meet requirements before execution. Validations run after coercions, giving you declarative data integrity checks.

See [Global Configuration](https://drexed.github.io/cmdx/getting_started/#validators) for custom validator setup.

## Usage

Define validation rules on attributes to enforce data requirements:

```ruby
class ProcessSubscription < CMDx::Task
  # Required field with presence validation
  attribute :user_id, presence: true

  # String with length constraints
  optional :preferences, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  required :tier_level, inclusion: { in: 1..5 }

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

Tip

Validations run after coercions, so you can validate the final coerced values rather than raw input.

## Built-in Validators

### Common Options

```ruby
class ProcessProduct < CMDx::Task
  # Allow nil
  attribute :tier_level, inclusion: {
    in: 1..5,
    allow_nil: true
  }

  # Conditionals
  optional :contact_email, format: {
    with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
    if: ->(value) { value.includes?("@") }
  }
  required :status, exclusion: {
    in: %w[recalled archived],
    unless: :product_sunsetted?
  }

  # Custom message
  attribute :title, length: {
    within: 5..100,
    message: "must be in optimal size"
  }

  def work
    # Your logic here...
  end

  private

  def product_defunct?(value)
    context.company.out_of_business? || value == "deprecated"
  end
end
```

This list of options is available to all validators:

| Option       | Description                                                           |
| ------------ | --------------------------------------------------------------------- |
| `:allow_nil` | Skip validation when value is `nil`                                   |
| `:if`        | Symbol, proc, lambda, or callable determining when to validate        |
| `:unless`    | Symbol, proc, lambda, or callable determining when to skip validation |
| `:message`   | Custom error message for validation failures                          |

### Absence

```ruby
class CreateUser < CMDx::Task
  attribute :honey_pot, absence: true

  attribute :honey_pot, absence: { message: "must be empty" }

  def work
    # Your logic here...
  end
end
```

| Options | Description                                       |
| ------- | ------------------------------------------------- |
| `true`  | Ensures value is nil, empty string, or whitespace |

### Exclusion

```ruby
class ProcessProduct < CMDx::Task
  attribute :status, exclusion: { in: %w[recalled archived] }

  def work
    # Your logic here...
  end
end
```

| Options           | Description                                  |
| ----------------- | -------------------------------------------- |
| `:in`             | The collection of forbidden values or range  |
| `:within`         | Alias for :in option                         |
| `:of_message`     | Custom message for discrete value exclusions |
| `:in_message`     | Custom message for range-based exclusions    |
| `:within_message` | Alias for :in_message option                 |

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

| Options    | Description                                 |
| ---------- | ------------------------------------------- |
| `regexp`   | Alias for :with option                      |
| `:with`    | Regex pattern that the value must match     |
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

| Options           | Description                                  |
| ----------------- | -------------------------------------------- |
| `:in`             | The collection of allowed values or range    |
| `:within`         | Alias for :in option                         |
| `:of_message`     | Custom message for discrete value inclusions |
| `:in_message`     | Custom message for range-based inclusions    |
| `:within_message` | Alias for :in_message option                 |

### Length

```ruby
class CreateBlogPost < CMDx::Task
  attribute :title, length: { within: 5..100 }

  def work
    # Your logic here...
  end
end
```

| Options               | Description                                        |
| --------------------- | -------------------------------------------------- |
| `:within`             | Range that the length must fall within (inclusive) |
| `:not_within`         | Range that the length must not fall within         |
| `:in`                 | Alias for :within                                  |
| `:not_in`             | Range that the length must not fall within         |
| `:min`                | Minimum allowed length                             |
| `:max`                | Maximum allowed length                             |
| `:is`                 | Exact required length                              |
| `:is_not`             | Length that is not allowed                         |
| `:within_message`     | Custom message for within/range validations        |
| `:in_message`         | Custom message for :in validation                  |
| `:not_within_message` | Custom message for not_within validation           |
| `:not_in_message`     | Custom message for not_in validation               |
| `:min_message`        | Custom message for minimum length validation       |
| `:max_message`        | Custom message for maximum length validation       |
| `:is_message`         | Custom message for exact length validation         |
| `:is_not_message`     | Custom message for is_not validation               |

### Numeric

```ruby
class CreateBlogPost < CMDx::Task
  attribute :word_count, numeric: { min: 100 }

  def work
    # Your logic here...
  end
end
```

| Options               | Description                                       |
| --------------------- | ------------------------------------------------- |
| `:within`             | Range that the value must fall within (inclusive) |
| `:not_within`         | Range that the value must not fall within         |
| `:in`                 | Alias for :within option                          |
| `:not_in`             | Alias for :not_within option                      |
| `:min`                | Minimum allowed value (inclusive, >=)             |
| `:max`                | Maximum allowed value (inclusive, \<=)            |
| `:is`                 | Exact value that must match                       |
| `:is_not`             | Value that must not match                         |
| `:within_message`     | Custom message for range validations              |
| `:not_within_message` | Custom message for exclusion validations          |
| `:min_message`        | Custom message for minimum validation             |
| `:max_message`        | Custom message for maximum validation             |
| `:is_message`         | Custom message for exact match validation         |
| `:is_not_message`     | Custom message for exclusion validation           |

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

| Options | Description                                           |
| ------- | ----------------------------------------------------- |
| `true`  | Ensures value is not nil, empty string, or whitespace |

## Declarations

Important

Custom validators must raise `CMDx::ValidationError` with a descriptive message.

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

Remove unwanted validators:

Warning

Each `deregister` call removes one validator. Use multiple calls for batch removals.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## Error Handling

Validation failures provide detailed, structured error messages:

```ruby
class CreateProject < CMDx::Task
  attribute :project_name,
    presence: true,
    length: { minimum: 3, maximum: 50 }
  optional :budget,
    numeric: { greater_than: 1000, less_than: 1000000 }
  required :priority,
    inclusion: { in: [:low, :medium, :high] }
  attribute :contact_email,
    format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

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
