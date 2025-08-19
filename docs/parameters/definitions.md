# Parameters - Definitions

Parameters define the interface between task callers and implementation, enabling automatic validation, type coercion, and method generation. They provide a contract to verify that task execution arguments match expected requirements and structure.

## Table of Contents

- [TLDR](#tldr)
- [Basic Parameter Definition](#basic-parameter-definition)
- [Parameter Sources](#parameter-sources)
- [Nested Parameters](#nested-parameters)
- [Advanced Features](#advanced-features)
- [Error Handling](#error-handling)

## TLDR

```ruby
class ProcessOrder < CMDx::Task
  # Required parameters - must be provided
  required :order_id, :customer_id

  # Optional parameters - can be nil
  optional :notes, :priority

  # Custom sources
  required :name, :email, source: :user

  # Nested parameters
  required :shipping_address do
    required :street, :city, :state
    optional :apartment
  end

  def work
    order_id    #=> value from call arguments
    name        #=> delegates to user.name
    street      #=> delegates to shipping_address.street
  end
end

# Usage
ProcessOrder.execute(
  order_id: 123,
  customer_id: 456,
  shipping_address: { street: "123 Main St", city: "Miami", state: "FL" }
)
```

## Basic Parameter Definition

> [!IMPORTANT]
> Required parameters must be provided in call arguments or task execution will fail. Optional parameters return `nil` when not provided.

```ruby
class CreateUser < CMDx::Task
  # Single parameter definitions
  required :email
  optional :name

  # Multiple parameters in one declaration
  required :age, :phone
  optional :bio, :website

  # Parameters with type coercion and validation
  required :age, type: :integer, numeric: { min: 18 }
  optional :tags, type: :array, default: []

  def work
    # All parameters become instance methods
    user = User.create!(
      email: email,           # Required - guaranteed to be present
      name: name,             # Optional - may be nil
      age: age,               # Required integer, validated >= 18
      phone: phone,           # Required - guaranteed to be present
      bio: bio,               # Optional - may be nil
      tags: tags              # Optional array with default []
    )

    user
  end
end

# Parameters passed as keyword arguments
CreateUser.execute(
  email: "user@example.com",
  age: 25,
  phone: "555-0123",
  name: "John Doe",
  tags: ["premium", "beta"]
)
```

## Parameter Sources

Parameters delegate to source objects within the task context. The default source is `:context`, but any accessible method or object can serve as a parameter source.

> [!NOTE]
> Sources allow parameters to pull values from different objects instead of just call arguments.

### Default Context Source

```ruby
class UpdateProfile < CMDx::Task
  # Default source is :context
  required :user_id
  optional :avatar_url

  # Explicitly specify context source
  required :email, source: :context

  def work
    user = User.find(user_id)     # From context.user_id
    user.update!(
      email: email,               # From context.email
      avatar_url: avatar_url      # From context.avatar_url
    )
  end
end
```

### Custom Object Sources

```ruby
class GenerateInvoice < CMDx::Task
  # Delegate to user object
  required :name, :email, source: :user

  # Delegate to order object
  required :total, :items, source: :order
  optional :discount, source: :order

  def work
    Invoice.create!(
      customer_name: name,        # From user.name
      customer_email: email,      # From user.email
      amount: total,              # From order.total
      line_items: items,          # From order.items
      discount_amount: discount   # From order.discount
    )
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def order
    @order ||= user.orders.find(context.order_id)
  end
end

GenerateInvoice.execute(user_id: 123, order_id: 456)
```

### Dynamic Sources

```ruby
class CalculatePermissions < CMDx::Task
  # Proc/Lambda source for dynamic resolution
  required :current_user, source: ->(task) { User.find(task.context.user_id) }
  required :company_name, source: proc { Company.find_by(context.company_id).name }

  # Method symbol sources
  required :role, source: :determine_user_role
  optional :access_level, source: :calculate_access_level

  def work
    {
      user: current_user.name,  # Resolved via lambda
      company: company_name,    # Resolved via proc
      role: role,               # From determine_user_role method
      access: access_level      # From calculate_access_level method
    }
  end

  private

  def determine_user_role
    current_user.admin? ? "admin" : "user"
  end

  def calculate_access_level
    case role
    when "admin" then "full"
    when "user" then "limited"
    else "none"
    end
  end
end
```

## Nested Parameters

Nested parameters enable complex parameter structures where child parameters automatically inherit their parent as the source. This allows validation and access of structured data.

> [!TIP]
> Child parameters are only required when their parent parameter is provided, enabling flexible optional structures.

```ruby
class CreateShipment < CMDx::Task
  required :order_id

  # Required parent with required children
  required :shipping_address do
    required :street, :city, :state, :zip
    optional :apartment, :instructions
  end

  # Optional parent with conditional children
  optional :billing_address do
    required :street, :city    # Only required if billing_address provided
    optional :same_as_shipping
  end

  # Multi-level nesting
  optional :special_handling do
    required :type

    optional :insurance do
      required :coverage_amount, type: :float
      optional :carrier
    end
  end

  def work
    shipment = Shipment.create!(
      order_id: order_id,

      # Access nested parameters directly
      ship_to_street: street,           # From shipping_address.street
      ship_to_city: city,               # From shipping_address.city
      ship_to_state: state,             # From shipping_address.state
      delivery_instructions: instructions,

      # Handle optional nested structures
      special_handling_type: type,      # From special_handling.type (if provided)
      insurance_amount: coverage_amount  # From special_handling.insurance.coverage_amount
    )

    shipment
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

## Advanced Features

### Parameter Method Generation

```ruby
class ProcessPayment < CMDx::Task
  required :amount, type: :float
  required :payment_method

  # Nested parameters generate flattened methods
  required :customer do
    required :id, :email

    optional :billing_address do
      required :street, :city
      optional :unit
    end
  end

  def work
    # All parameters accessible as instance methods
    payment = PaymentService.charge(
      amount: amount,                    # Direct parameter access
      method: payment_method,            # Direct parameter access
      customer_id: id,                   # From customer.id
      customer_email: email,             # From customer.email
      billing_street: street,            # From customer.billing_address.street
      billing_city: city                 # From customer.billing_address.city
    )

    payment
  end
end
```

### Parameter Introspection

```ruby
class IntrospectionExample < CMDx::Task
  required :name
  optional :age, type: :integer, default: 18

  required :address do
    required :street
    optional :unit
  end

  def work
    # Access parameter metadata
    params = self.class.parameters

    params.each do |param|
      puts "Parameter: #{param.name}"
      puts "Required: #{param.required?}"
      puts "Type: #{param.type}"
      puts "Default: #{param.default}" if param.has_default?
      puts "Source: #{param.source}"
      puts "---"
    end
  end
end
```

## Error Handling

> [!WARNING]
> Parameter validation failures result in structured error information with details about each failed parameter.

### Missing Required Parameters

```ruby
class RequiredParams < CMDx::Task
  required :user_id, :order_id
  required :shipping_address do
    required :street, :city
  end

  def work
    # Task logic
  end
end

# Missing required parameters
result = RequiredParams.execute(user_id: 123)
result.failed?  #=> true
result.metadata
# {
#   order_id is required. shipping_address is required.",
#   messages: {
#     order_id: ["is required"],
#     shipping_address: ["is required"]
#   }
# }

# Missing nested required parameters
result = RequiredParams.execute(
  user_id: 123,
  order_id: 456,
  shipping_address: { street: "123 Main St" }  # Missing city
)
result.failed?  #=> true
result.metadata
# {
#   city is required.",
#   messages: {
#     city: ["is required"]
#   }
# }
```

### Source Resolution Errors

```ruby
class SourceError < CMDx::Task
  required :name, source: :user
  required :status, source: :nonexistent_method

  def work
    # Task logic
  end

  private

  def user
    # This will raise an error
    raise StandardError, "User service unavailable"
  end
end

result = SourceError.call
result.failed?  #=> true
# Error propagated from source resolution failure
```

### Complex Validation Errors

```ruby
class ValidationError < CMDx::Task
  required :email, format: { with: /@/ }
  required :age, type: :integer, numeric: { min: 18, max: 120 }
  optional :phone, format: { with: /\A\d{10}\z/ }

  required :preferences do
    required :theme, inclusion: { in: %w[light dark] }
    optional :language, inclusion: { in: %w[en es fr] }
  end

  def work
    # Task logic
  end
end

# Multiple validation failures
result = ValidationError.execute(
  email: "invalid-email",
  age: "not-a-number",
  phone: "123",
  preferences: {
    theme: "purple",
    language: "invalid"
  }
)

result.failed?  #=> true
result.metadata
# {
#   email format is not valid. age could not coerce into an integer. phone format is not valid. theme purple is not included in the list. language invalid is not included in the list.",
#   messages: {
#     email: ["format is not valid"],
#     age: ["could not coerce into an integer"],
#     phone: ["format is not valid"],
#     theme: ["purple is not included in the list"],
#     language: ["invalid is not included in the list"]
#   }
# }
```

> [!TIP]
> Parameter validation occurs before the `execute` method executes, so you can rely on parameter presence and types within your task logic.

---

- **Prev:** [Configuration](../configuration.md)
- **Next:** [Parameters - Namespacing](namespacing.md)
