# Parameters - Definitions

Parameters provide a contract to verify that task execution arguments match expected requirements and structure. They define the interface between task callers and task implementation, enabling automatic validation, type coercion, and method generation for clean parameter access within tasks.

## Parameter Fundamentals

Parameters are defined using `required` and `optional` class methods that automatically create accessor methods within task instances. Parameters are resolved from call arguments and made available as instance methods matching the parameter names.

### Basic Parameter Definition

```ruby
class ProcessOrderTask < CMDx::Task
  # Must be provided in call arguments
  required :order_id

  # Optional - returns nil if not provided
  optional :priority

  # Multiple parameters in one declaration
  required :customer_id, :product_id
  optional :notes, :metadata

  def call
    order_id    #=> 123 (from call arguments)
    priority    #=> "high" (from call arguments) or nil
    customer_id #=> 456 (from call arguments)
    notes       #=> "Special handling" or nil
  end
end

# Parameters passed as keyword arguments
ProcessOrderTask.call(
  order_id: 123,
  customer_id: 456,
  priority: "high",
  notes: "Special handling"
)
```

### Parameter Requirements

- **Required parameters** must be provided in call arguments or task execution fails
- **Optional parameters** return `nil` if not provided in call arguments
- **Parameter names** become instance methods accessible within the task
- **Call arguments** are matched to parameter names using symbol keys

## Parameter Sources

Parameters delegate to source objects within the task context. The default source is `:context`, but any accessible method or object can serve as a parameter source.

### Default Context Source

```ruby
class UpdateUserTask < CMDx::Task
  # Delegates to context.user_id (default source)
  required :user_id

  # Explicitly specified context source
  required :email, source: :context

  def call
    user_id #=> delegates to context.user_id
    email   #=> delegates to context.email
  end
end

# Context receives all call arguments
UpdateUserTask.call(user_id: 123, email: "user@example.com")
```

### Custom Object Sources

```ruby
class ProcessUserOrderTask < CMDx::Task
  # Delegate to user object
  required :user_id, source: :user
  required :name, source: :user

  # Delegate to order object
  required :total, source: :order
  optional :discount, source: :order

  def call
    user_id  #=> delegates to user.user_id
    name     #=> delegates to user.name
    total    #=> delegates to order.total
    discount #=> delegates to order.discount
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def order
    @order ||= user.orders.find(context.order_id)
  end
end

# Only need IDs in call arguments
ProcessUserOrderTask.call(user_id: 123, order_id: 456)
```

### Dynamic Sources

```ruby
class ProcessDynamicParameterTask < CMDx::Task
  # Lambda source for dynamic resolution
  required :company_name, source: -> { user.company }

  # Proc source with complex logic
  optional :region, source: proc {
    user.address&.country == "US" ? user.address.state : user.address.country
  }

  # Method name sources
  required :account_type, source: :determine_account_type
  optional :access_level, source: "calculate_access_level"

  def call
    company_name  #=> resolved via lambda
    region        #=> resolved via proc logic
    account_type  #=> result of determine_account_type method
    access_level  #=> result of calculate_access_level method
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def determine_account_type
    context.user.premium? ? "premium" : "standard"
  end

  def calculate_access_level
    context.user.admin? ? "admin" : "user"
  end
end
```

## Nested Parameters

Nested parameters allow complex parameter structures where child parameters automatically inherit their parent as the source. This enables validation and access of structured data while maintaining clean parameter definitions.

### Basic Nesting

```ruby
class ProcessShippingTask < CMDx::Task
  # Parent parameter with nested children
  required :shipping_address do
    required :street, :city, :state
    optional :apartment, :unit
  end

  # Optional parent with required children
  optional :billing_address do
    required :street, :city  # Only required if billing_address provided
    optional :same_as_shipping
  end

  def call
    # Parent parameter access
    shipping_address #=> { street: "123 Main St", city: "Miami", state: "FL" }

    # Child parameter access (delegates to parent)
    street     #=> "123 Main St" (from shipping_address.street)
    city       #=> "Miami" (from shipping_address.city)
    apartment  #=> nil (optional, not provided)

    # Conditional child access
    if billing_address
      # These are available because billing_address was provided
      billing_street = street  # Would access billing_address.street
      billing_city = city      # Would access billing_address.city
    end
  end
end

# Nested data in call arguments
ProcessShippingTask.call(
  shipping_address: {
    street: "123 Main St",
    city: "Miami",
    state: "FL"
  },
  billing_address: {
    street: "456 Oak Ave",
    city: "Orlando"
  }
)
```

### Multi-Level Nesting

```ruby
class ProcessComplexDataTask < CMDx::Task
  required :user do
    required :name, :email

    required :profile do
      required :age
      optional :bio

      optional :preferences do
        optional :theme, :language
        required :notifications  # Required if preferences provided
      end
    end

    optional :addresses do
      required :primary do
        required :street, :city
        optional :apartment
      end
      optional :secondary
    end
  end

  def call
    # Access at any nesting level
    name        #=> delegates to user.name
    email       #=> delegates to user.email
    age         #=> delegates to user.profile.age
    theme       #=> delegates to user.profile.preferences.theme
    street      #=> delegates to user.addresses.primary.street
  end
end
```

### Nested Parameter Validation

```ruby
class ValidateOrderTask < CMDx::Task
  required :order do
    required :items, type: :array
    required :total, type: :float

    optional :customer do
      required :email, format: { with: /@/ }  # Required if customer provided
      optional :phone, format: { with: /\d{10}/ }
    end

    optional :shipping do
      required :method, inclusion: { in: %w[standard express overnight] }
      required :address do  # Required if shipping provided
        required :street, :city, :state
        optional :apartment
      end
    end
  end

  def call
    # All nested validations automatically enforced
    items  #=> validated as array
    total  #=> validated as float
    email  #=> validated with regex (if customer provided)
    method #=> validated against inclusion list (if shipping provided)
  end
end
```

## Parameter Method Generation

Parameters automatically generate accessor methods with configurable naming
to prevent conflicts and enable flexible parameter access patterns.

### Method Name Resolution

```ruby
class ProcessMethodGenerationTask < CMDx::Task

  # Standard method generation
  required :user_id        # Generates: user_id method

  # Custom source with method name
  required :account_name, source: :account  # Generates: account_name method

  # Nested parameter method generation
  required :address do
    required :street       # Generates: street method (delegates to address.street)
    required :postal_code  # Generates: postal_code method
  end

  def call
    user_id      #=> accesses context.user_id
    account_name #=> accesses account.account_name
    street       #=> accesses address.street
    postal_code  #=> accesses address.postal_code
  end

  private

  def account
    @account ||= Account.find(user_id)
  end

end
```

### Parameter Options and Configuration

Parameters support extensive configuration options for validation, coercion, defaults, and custom behavior:

```ruby
class ProcessConfigurableParameterTask < CMDx::Task
  # Basic configuration
  required :user_id, type: :integer
  optional :priority, type: :string, default: "normal"

  # Validation configuration
  required :email,
    type: :string,
    format: { with: /@/ },
    presence: true

  # Complex configuration
  optional :metadata,
    type: :hash,
    default: {},
    custom: { validator: MetadataValidator }

  # Nested with configuration
  required :shipping_info do
    required :method,
      type: :string,
      inclusion: { in: %w[standard express] }

    required :address, type: :hash do
      required :street, :city, type: :string, presence: true
      required :zip, type: :string, format: { with: /\A\d{5}\z/ }
    end
  end

  def call
    # All parameters available with validation and coercion applied
    user_id       #=> integer (coerced)
    priority      #=> "normal" (default) or provided value
    email         #=> validated string with @ symbol
    metadata      #=> hash (coerced) with custom validation
    method        #=> validated against inclusion list
    street        #=> validated non-empty string
    zip           #=> validated 5-digit string
  end
end
```

## Parameter Introspection

Tasks provide access to their parameter definitions for introspection, debugging, and dynamic behavior:

```ruby
class ProcessIntrospectionTask < CMDx::Task
  required :user_id, type: :integer
  optional :email, type: :string, format: { with: /@/ }

  required :address do
    required :street, :city
    optional :apartment
  end

  def call
    # Access parameter definitions
    params = self.class.cmd_parameters

    params.size                    #=> 3 (user_id, email, address)
    params.first.name              #=> :user_id
    params.first.required?         #=> true
    params.first.type              #=> :integer

    # Nested parameter access
    address_param = params.find { |p| p.name == :address }
    address_param.children.size    #=> 3 (street, city, apartment)
    address_param.children.first.name      #=> :street
    address_param.children.first.required? #=> true

    # Parameter serialization
    params.to_h  #=> Array of parameter hash representations
    params.to_s  #=> Human-readable parameter descriptions
  end
end
```

## Error Handling

Parameter validation failures result in structured error information:

```ruby
class ProcessValidationExampleTask < CMDx::Task
  required :age, type: :integer, numeric: { min: 18, max: 120 }
  required :email, type: :string, format: { with: /@/ }
  optional :phone, type: :string, format: { with: /\A\d{10}\z/ }

  def call
    # Task logic here
  end
end

# Invalid parameters
result = ProcessValidationExampleTask.call(
  age: "invalid",
  email: "not-an-email",
  phone: "123"
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "age could not coerce into an integer. email format is not valid. phone format is not valid.",
#     messages: {
#       age: ["could not coerce into an integer"],
#       email: ["format is not valid"],
#       phone: ["format is not valid"]
#     }
#   }
```

## Best Practices

### Parameter Design

- **Use descriptive parameter names** that clearly indicate their purpose
- **Prefer `required` for essential business data**, `optional` for configuration
- **Group related parameters using nesting** for complex data structures
- **Use appropriate types** for automatic coercion and validation

### Source Selection

- **Use default `:context` source** for simple call arguments
- **Use custom sources** for computed or derived values
- **Use proc/lambda sources** for dynamic resolution
- **Avoid complex logic in source definitions** - delegate to private methods

### Validation Strategy

- **Apply validation at parameter level** rather than in business logic
- **Use built-in validators** for common patterns (format, presence, inclusion)
- **Create custom validators** for business-specific rules
- **Provide clear, actionable error messages**

### Nested Parameters

- **Use nesting for logically grouped parameters**
- **Keep nesting levels reasonable** (typically 2-3 levels maximum)
- **Make parent parameters optional** when child parameters are conditional
- **Consider the trade-off** between nesting and flat parameter structures

---

- **Prev:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- **Next:** [Parameters - Namespacing](https://github.com/drexed/cmdx/blob/main/docs/parameters/namespacing.md)
