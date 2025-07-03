# Parameters - Definitions

Parameters provide a contract to verify that task execution arguments match expected requirements and structure. They define the interface between task callers and task implementation, enabling automatic validation, type coercion, and method generation for clean parameter access within tasks.

## Table of Contents

- [Parameter Fundamentals](#parameter-fundamentals)
- [Parameter Sources](#parameter-sources)
- [Nested Parameters](#nested-parameters)
- [Parameter Method Generation](#parameter-method-generation)
- [Parameter Options and Configuration](#parameter-options-and-configuration)
- [Parameter Introspection](#parameter-introspection)
- [Error Handling](#error-handling)

## Parameter Fundamentals

Parameters are defined using `required` and `optional` class methods that automatically create accessor methods within task instances. Parameters are matched from call arguments and made available as instance methods.

> [!IMPORTANT]
> Required parameters must be provided in call arguments or task execution will fail.

### Basic Parameter Definition

```ruby
class CreateOrderTask < CMDx::Task
  # Must be provided in call arguments
  required :order_id

  # Optional - returns nil if not provided
  optional :priority

  # Multiple parameters in one declaration
  required :customer_id, :product_id
  optional :notes, :shipping_method

  def call
    order_id        #=> 123 (from call arguments)
    priority        #=> "high" or nil
    customer_id     #=> 456 (from call arguments)
    shipping_method #=> "express" or nil
  end
end

# Parameters passed as keyword arguments
CreateOrderTask.call(
  order_id: 123,
  customer_id: 456,
  product_id: 789,
  priority: "high",
  shipping_method: "express"
)
```

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

UpdateUserTask.call(user_id: 123, email: "user@example.com")
```

### Custom Object Sources

```ruby
class ProcessUserOrderTask < CMDx::Task
  # Delegate to user object
  required :name, :email, source: :user

  # Delegate to order object
  required :total, :status, source: :order
  optional :discount, source: :order

  def call
    name     #=> delegates to user.name
    email    #=> delegates to user.email
    total    #=> delegates to order.total
    status   #=> delegates to order.status
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

ProcessUserOrderTask.call(user_id: 123, order_id: 456)
```

### Dynamic Sources

```ruby
class ProcessDynamicParameterTask < CMDx::Task
  # Lambda source for dynamic resolution
  required :company_name, source: -> { user.company }

  # Method name sources
  required :account_type, source: :determine_account_type
  optional :access_level, source: :calculate_access_level

  def call
    company_name #=> resolved via lambda
    account_type #=> result of determine_account_type method
    access_level #=> result of calculate_access_level method
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def determine_account_type
    user.premium? ? "premium" : "standard"
  end

  def calculate_access_level
    user.admin? ? "admin" : "user"
  end
end
```

## Nested Parameters

Nested parameters allow complex parameter structures where child parameters automatically inherit their parent as the source. This enables validation and access of structured data.

> [!NOTE]
> Child parameters are only required when their parent parameter is provided.

### Basic Nesting

```ruby
class CreateShippingLabelTask < CMDx::Task
  # Parent parameter with nested children
  required :shipping_address do
    required :street, :city, :state, :zip_code
    optional :apartment_number
  end

  # Optional parent with required children
  optional :billing_address do
    required :street, :city # Only required if billing_address provided
    optional :same_as_shipping
  end

  def call
    # Parent parameter access
    shipping_address #=> { street: "123 Main St", city: "Miami", ... }

    # Child parameter access (delegates to parent)
    street           #=> "123 Main St" (from shipping_address.street)
    city             #=> "Miami" (from shipping_address.city)
    apartment_number #=> nil (optional, not provided)
  end
end

CreateShippingLabelTask.call(
  shipping_address: {
    street: "123 Main St",
    city: "Miami",
    state: "FL",
    zip_code: "33101"
  }
)
```

### Multi-Level Nesting

```ruby
class CreateUserProfileTask < CMDx::Task
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
  end

  def call
    # Access at any nesting level
    name  #=> delegates to user.name
    email #=> delegates to user.email
    age   #=> delegates to user.profile.age
    theme #=> delegates to user.profile.preferences.theme
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
      required :email, format: { with: /@/ }
      optional :phone, format: { with: /\A\d{10}\z/ }
    end
  end

  def call
    items #=> validated as array
    total #=> validated as float
    email #=> validated with regex (if customer provided)
    phone #=> validated phone format (if provided)
  end
end
```

## Parameter Method Generation

Parameters automatically generate accessor methods that delegate to their configured sources.

> [!TIP]
> Parameter names become instance methods accessible within the task.

```ruby
class ProcessPaymentTask < CMDx::Task
  # Standard method generation
  required :payment_id # Generates: payment_id method

  # Custom source with method name
  required :account_name, source: :account # Generates: account_name method

  # Nested parameter method generation
  required :billing_info do
    required :card_number  # Generates: card_number method
    required :expiry_date  # Generates: expiry_date method
  end

  def call
    payment_id   #=> accesses context.payment_id
    account_name #=> accesses account.account_name
    card_number  #=> accesses billing_info.card_number
    expiry_date  #=> accesses billing_info.expiry_date
  end

  private

  def account
    @account ||= Account.find(context.account_id)
  end
end
```

## Parameter Options and Configuration

Parameters support extensive configuration options for validation, coercion, defaults, and custom behavior:

```ruby
class ProcessOrderTask < CMDx::Task
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
    default: {}

  # Nested with configuration
  required :shipping_info do
    required :method,
      type: :string,
      inclusion: { in: %w[standard express overnight] }

    required :address, type: :hash do
      required :street, :city, type: :string, presence: true
      required :zip, type: :string, format: { with: /\A\d{5}\z/ }
    end
  end

  def call
    user_id  #=> integer (coerced)
    priority #=> "normal" (default) or provided value
    email    #=> validated string with @ symbol
    metadata #=> hash (coerced)
    method   #=> validated against inclusion list
    street   #=> validated non-empty string
    zip      #=> validated 5-digit string
  end
end
```

## Parameter Introspection

Tasks provide access to their parameter definitions for introspection and debugging:

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

    params.size            #=> 3 (user_id, email, address)
    params.first.name      #=> :user_id
    params.first.required? #=> true
    params.first.type      #=> :integer

    # Nested parameter access
    address_param = params.find { |p| p.name == :address }
    address_param.children.size            #=> 3
    address_param.children.first.name      #=> :street
    address_param.children.first.required? #=> true
  end
end
```

## Error Handling

Parameter validation failures result in structured error information:

> [!WARNING]
> Invalid parameters will cause task execution to fail with detailed error messages.

```ruby
class ValidateUserTask < CMDx::Task
  required :age, type: :integer, numeric: { min: 18, max: 120 }
  required :email, type: :string, format: { with: /@/ }
  optional :phone, type: :string, format: { with: /\A\d{10}\z/ }

  def call
    # Task logic here
  end
end

# Invalid parameters
result = ValidateUserTask.call(
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

---

- **Prev:** [Configuration](../configuration.md)
- **Next:** [Parameters - Namespacing](namespacing.md)
