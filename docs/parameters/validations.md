# Parameters - Validations

Parameter validations ensure task arguments meet specified requirements before execution begins. Validations run after coercions and provide declarative rules for data integrity, supporting both built-in validators and custom validation logic.

## Table of Contents

- [Usage](#usage)
- [Built-in Validators](#built-in-validators)
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
  attribute :notes, type: :string, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  attribute :quantity, type: :integer, inclusion: { in: 1..100 }

  # Format validation for email
  attribute :email, type: :string, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

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

| Validator | Options | Description | Examples |
|-----------|---------|-------------|----------|
| `presence` | `true` | Ensures value is not nil, empty string, or whitespace | `nil` → ❌<br>`""` → ❌<br>`" "` → ❌<br>`"value"` → ✅ |
| `exclusion` | `in: [...]` | Value must not be in specified collection | `exclusion: { in: ["admin", "root"] }` |
| `format` | `/\A...\z/` | Value must match regex pattern | `format: /\A\d{5}\z/` for 5-digit codes |
| `inclusion` | `in: [...]` | Value must be in specified collection | `inclusion: { in: ["pending", "approved", "rejected"] }` |
| `length` | `minimum`, `maximum`, `is` | String/array length constraints | `length: { minimum: 3, maximum: 50 }` |
| `numeric` | `greater_than`, `less_than`, `equal_to` | Numeric value constraints | `numeric: { greater_than: 0, less_than: 1000 }` |

## Declarations

> [!IMPORTANT]
> Custom validators must raise a CMDx::ValidationError and its
> message is used as part of the fault reason and metadata.

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

  attribute :domain_name, type: :string, domain: true
  attribute :subdomain, type: :string, domain: true, allow_nil: true
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

Validation failures provide detailed error information including parameter paths, validation rules, and specific failure reasons:

```ruby
class CreateUser < CMDx::Task
  attribute :username, type: :string, presence: true, length: { minimum: 3, maximum: 20 }
  attribute :age, type: :integer, numeric: { greater_than: 13, less_than: 120 }
  attribute :role, type: :symbol, inclusion: { in: [:user, :moderator, :admin] }
  attribute :email, type: :string, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

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

- **Prev:** [Parameters - Coercions](coercions.md)
- **Next:** [Parameters - Defaults](defaults.md)
