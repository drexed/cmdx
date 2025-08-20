# Attributes - Definitions

Attributes define the interface between task callers and implementation, enabling automatic validation, type coercion, and method generation. They provide a contract to verify that task execution arguments match expected requirements and structure.

## Table of Contents

- [Declarations](#declarations)
  - [Optional](#optional)
  - [Required](#required)
- [Sources](#sources)
  - [Context](#context)
  - [Symbol References](#symbol-references)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)
- [Nesting](#nesting)
- [Error Handling](#error-handling)

## Declarations

> [!TIP]
> Prefer using the `required` and `optional` alias for `attributes` for brevity and to clearly signal intent.

### Optional

Optional attributes return `nil` when not provided.

```ruby
class CreateUser < CMDx::Task
  attribute :email
  attributes :age, :ssn

  # Alias for attributes (preferred)
  optional :phone
  optional :sex, :tags

  def work
    email #=> "user@example.com"
    age   #=> 25
    ssn   #=> nil
    phone #=> nil
    sex   #=> nil
    tags  #=> ["premium", "beta"]
  end
end

# Attributes passed as keyword arguments
CreateUser.execute(
  email: "user@example.com",
  age: 25,
  tags: ["premium", "beta"]
)
```

### Required

Required attributes must be provided in call arguments or task execution will fail.

```ruby
class CreateUser < CMDx::Task
  attribute :email, required: true
  attributes :age, :ssn, required: true

  # Alias for attributes => required: true (preferred)
  required :phone
  required :sex, :tags

  def work
    email #=> "user@example.com"
    age   #=> 25
    ssn   #=> "123-456"
    phone #=> "888-9909"
    sex   #=> :male
    tags  #=> ["premium", "beta"]
  end
end

# Attributes passed as keyword arguments
CreateUser.execute(
  email: "user@example.com",
  age: 25,
  ssn: "123-456",
  phone: "888-9909",
  sex: :male,
  tags: ["premium", "beta"]
)
```

## Sources

Attributes delegate to accessible objects within the task. The default source is `:context`, but any accessible method or object can serve as an attribute source.

### Context

```ruby
class UpdateProfile < CMDx::Task
  # Default source is :context
  required :user_id
  optional :avatar_url

  # Explicitly specify context source
  attribute :email, source: :context

  def work
    user_id    #=> context.user_id
    email      #=> context.email
    avatar_url #=> context.avatar_url
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic source values:

```ruby
class UpdateProfile < CMDx::Task
  attributes :email, :settings, source: :user

  # Access from declared attributes
  attribute :email_token, source: :settings

  def work
    # Your logic here...
  end

  private

  def user
    @user ||= User.find(1)
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic source values:

```ruby
class UpdateProfile < CMDx::Task
  # Proc
  attribute :email, source: proc { Current.user }

  # Lambda
  attribute :email, source: -> { Current.user }
end
```

### Class or Module

For complex source logic, use classes or modules:

```ruby
class UserSourcer
  def self.call(task)
    User.find(task.context.user_id)
  end
end

class UpdateProfile < CMDx::Task
  # Class or Module
  attribute :email, source: UserSourcer

  # Instance
  attribute :email, source: UserSourcer.new
end
```

## Nesting

Nested attributes enable complex attribute structures where child attributes automatically inherit their parent as the source. This allows validation and access of structured data.

> [!IMPORTANT]
> All options available to top-level attributes are available to nested attributes, eg: naming, coercions, and validations

```ruby
class CreateShipment < CMDx::Task
  # Required parent with required children
  required :shipping_address do
    required :street, :city, :state, :zip
    optional :apartment
    attribute :instructions
  end

  # Optional parent with conditional children
  optional :billing_address do
    required :street, :city # Only required if billing_address provided
    optional :same_as_shipping, prefix: true
  end

  # Multi-level nesting
  attribute :special_handling do
    required :type

    optional :insurance do
      required :coverage_amount
      optional :carrier
    end
  end

  def work
    shipping_address #=> { street: "123 Main St" ... }
    street           #=> "123 Main St"
    apartment        #=> nil
  end
end

CreateShipment.execute(
  order_id: 123,
  shipping_address: {
    street: "123 Main St",
    city: "Miami",
    state: "FL",
    zip: "33101",
    instructions: "Leave at door"
  },
  special_handling: {
    type: "fragile",
    insurance: {
      coverage_amount: 500.00,
      carrier: "FedEx"
    }
  }
)
```

> [!TIP]
> Child attributes are only required when their parent attribute is provided, enabling flexible optional structures.

## Error Handling

Attribute validation failures result in structured error information with details about each failed attribute.

> [!IMPORTANT]
> Nested attributes are only ever evaluated when the parent attribute is available and valid.

```ruby
class ProcessOrder < CMDx::Task
  required :user_id, :order_id
  required :shipping_address do
    required :street, :city
  end

  def work
    # Your logic here...
  end
end

# Missing required top-level attributes
result = ProcessOrder.execute(user_id: 123)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "order_id is required. shipping_address is required."
result.metadata #=> {
                #     messages: {
                #       order_id: ["is required"],
                #       shipping_address: ["is required"]
                #     }
                #   }

# Missing required nested attributes
result = ProcessOrder.execute(
  user_id: 123,
  order_id: 456,
  shipping_address: { street: "123 Main St" } # Missing city
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "city is required."
result.metadata #=> {
                #     messages: {
                #       city: ["is required"]
                #     }
                #   }
```

---

- **Prev:** [Configuration](../configuration.md)
- **Next:** [Attributes - Naming](naming.md)
