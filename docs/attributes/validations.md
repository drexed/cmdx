# Attributes - Validations

Attribute validations ensure task arguments meet specified requirements before execution begins. Validations run after coercions and provide declarative rules for data integrity, supporting both built-in validators and custom validation logic.

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
class ProcessOrder < CMDx::Task
  # Required field with presence validation
  attribute :customer_id, presence: true

  # String with length constraints
  attribute :notes, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  attribute :quantity, inclusion: { in: 1..100 }

  # Format validation for email
  attribute :email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    customer_id #=> "12345"
    notes       #=> "Please deliver to front door"
    quantity    #=> 5
    email       #=> "customer@example.com"
  end
end

ProcessOrder.execute(
  customer_id: "12345",
  notes: "Please deliver to front door",
  quantity: 5,
  email: "customer@example.com"
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
class ProcessOrder < CMDx::Task
  attribute :status, exclusion: { in: %w[out_of_stock discontinued] }

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
class ProcessOrder < CMDx::Task
  attribute :email, exclusion: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  attribute :email, exclusion: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }

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
class ProcessOrder < CMDx::Task
  attribute :status, inclusion: { in: %w[preorder in_stock] }

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
class CreateUser < CMDx::Task
  attribute :username, length: { within: 1..30 }

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
class CreateUser < CMDx::Task
  attribute :age, length: { min: 13 }

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
class CreateUser < CMDx::Task
  attribute :accept_tos, presence: true

  attribute :accept_tos, presence: { message: "needs to be accepted" }

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
> Custom validators must raise a CMDx::ValidationError and its message is used as part of the fault reason and metadata.

### Proc or Lambda

Use anonymous functions for simple validation logic:

```ruby
class CreateWebsite < CMDx::Task
  # Proc
  register :validator, :domain, proc do |value, options = {}|
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  end

  # Lambda
  register :validator, :domain, ->(value, options = {}) {
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  }
end
```

### Class or Module

Register custom validation logic for specialized requirements:

```ruby
class DomainValidator
  def self.call(value, options = {})
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  end
end

class CreateWebsite < CMDx::Task
  register :validator, :domain, DomainValidator

  attribute :domain_name, domain: true
end
```

## Removals

Remove custom validators when no longer needed:

```ruby
class CreateWebsite < CMDx::Task
  deregister :validator, :domain
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Error Handling

Validation failures provide detailed error information including attribute paths, validation rules, and specific failure reasons:

```ruby
class CreateUser < CMDx::Task
  attribute :username, presence: true, length: { minimum: 3, maximum: 20 }
  attribute :age, numeric: { greater_than: 13, less_than: 120 }
  attribute :role, inclusion: { in: [:user, :moderator, :admin] }
  attribute :email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    # Your logic here...
  end
end

result = CreateUser.execute(
  username: "ab",           # Too short
  age: 10,                  # Too young
  role: :superuser,         # Not in allowed list
  email: "invalid-email"    # Invalid format
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "username is too short (minimum is 3 characters). age must be greater than 13. role is not included in the list. email is invalid."
result.metadata #=> {
                #     messages: {
                #       username: ["is too short (minimum is 3 characters)"],
                #       age: ["must be greater than 13"],
                #       role: ["is not included in the list"],
                #       email: ["is invalid"]
                #     }
                #   }
```

---

- **Prev:** [Attributes - Coercions](coercions.md)
- **Next:** [Attributes - Defaults](defaults.md)
