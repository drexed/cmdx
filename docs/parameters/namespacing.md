# Parameters - Namespacing

Parameter namespacing provides method name customization to prevent conflicts and enable flexible parameter access patterns. When parameters share names with existing methods or when multiple parameters from different sources have the same name, namespacing ensures clean method resolution within tasks.

## Table of Contents

- [TLDR](#tldr)
- [Namespacing Fundamentals](#namespacing-fundamentals)
- [Fixed Value Namespacing](#fixed-value-namespacing)
- [Dynamic Source-Based Namespacing](#dynamic-source-based-namespacing)
- [Conflict Resolution](#conflict-resolution)
- [Advanced Patterns](#advanced-patterns)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Fixed prefixes/suffixes
required :name, prefix: "user_"        # → user_name method
required :email, suffix: "_address"    # → email_address method

# Dynamic source-based namespacing
required :id, prefix: true             # → context_id method (from context source)
required :name, source: :profile, suffix: true  # → name_profile method

# Conflict resolution
required :context, suffix: "_data"     # Avoids CMDx::Task#context method
required :name, prefix: "customer_"    # Avoids Ruby's Object#name method

# Call arguments always use original parameter names
TaskClass.call(name: "John", email: "john@example.com", context: {...})
```

## Namespacing Fundamentals

> [!IMPORTANT]
> Namespacing modifies only the generated accessor method names within tasks. Parameter names in call arguments remain unchanged, ensuring a clean external interface.

### Namespacing Options

| Option | Type | Description | Example |
|--------|------|-------------|---------|
| `prefix:` | String/Symbol | Fixed prefix | `prefix: "user_"` → `user_name` |
| `prefix:` | Boolean | Dynamic prefix from source | `prefix: true` → `context_name` |
| `suffix:` | String/Symbol | Fixed suffix | `suffix: "_data"` → `name_data` |
| `suffix:` | Boolean | Dynamic suffix from source | `suffix: true` → `name_context` |

## Fixed Value Namespacing

Use string or symbol values for consistent prefixes or suffixes:

```ruby
class UpdateCustomerTask < CMDx::Task
  required :id, prefix: "customer_"
  required :name, prefix: "customer_"
  required :email, suffix: "_address"
  required :phone, suffix: "_number"

  def call
    customer = Customer.find(customer_id)
    customer.update!(
      name: customer_name,
      email: email_address,
      phone: phone_number
    )
  end
end

# Call uses original parameter names
UpdateCustomerTask.call(
  id: 123,
  name: "Jane Smith",
  email: "jane@example.com",
  phone: "555-0123"
)
```

## Dynamic Source-Based Namespacing

> [!TIP]
> Use `true` with `prefix:` or `suffix:` to automatically generate method names based on parameter sources, creating self-documenting code.

```ruby
class GenerateInvoiceTask < CMDx::Task
  required :id, prefix: true                          # → context_id
  required :amount, source: :order, prefix: true      # → order_amount
  required :tax_rate, source: :settings, suffix: true # → tax_rate_settings

  def call
    customer = Customer.find(context_id)
    total = order_amount * (1 + tax_rate_settings)

    Invoice.create!(
      customer: customer,
      amount: order_amount,
      tax_rate: tax_rate_settings,
      total: total
    )
  end

  private

  def order
    @order ||= Order.find(context.order_id)
  end

  def settings
    @settings ||= TaxSettings.for_region(context.region)
  end
end
```

## Conflict Resolution

> [!WARNING]
> Parameter names that conflict with existing Ruby or CMDx methods can cause unexpected behavior. Always use namespacing to avoid method collisions.

### Ruby Method Conflicts

```ruby
class ProcessAccountTask < CMDx::Task
  # Avoid conflicts with Ruby's built-in methods
  required :name, prefix: "account_"      # Not Object#name
  required :class, suffix: "_type"        # Not Object#class
  required :method, prefix: "http_"       # Not Object#method

  def call
    Account.create!(
      name: account_name,
      classification: class_type,
      request_method: http_method
    )
  end
end
```

### CMDx Method Conflicts

```ruby
class DataProcessingTask < CMDx::Task
  # Avoid conflicts with CMDx::Task methods
  required :context, suffix: "_payload"   # Not CMDx::Task#context
  required :result, prefix: "api_"        # Not CMDx::Task#result
  required :logger, suffix: "_config"     # Not CMDx::Task#logger

  def call
    process_data(context_payload, api_result, logger_config)
  end
end
```

### Multi-Source Disambiguation

```ruby
class SyncDataTask < CMDx::Task
  # Customer and vendor both have overlapping attributes
  required :id, source: :customer, prefix: "customer_"
  required :name, source: :customer, prefix: "customer_"
  required :email, source: :customer, prefix: "customer_"

  required :id, source: :vendor, prefix: "vendor_"
  required :name, source: :vendor, prefix: "vendor_"
  required :email, source: :vendor, prefix: "vendor_"

  def call
    sync_customer_data(customer_id, customer_name, customer_email)
    sync_vendor_data(vendor_id, vendor_name, vendor_email)
  end

  private

  def customer
    @customer ||= Customer.find(context.customer_id)
  end

  def vendor
    @vendor ||= Vendor.find(context.vendor_id)
  end
end
```

## Advanced Patterns

### Hierarchical Parameter Organization

```ruby
class CreateShipmentTask < CMDx::Task
  required :address, source: :origin, prefix: "origin_" do
    required :street, :city, :state, :zip_code
  end

  required :address, source: :destination, prefix: "destination_" do
    required :street, :city, :state, :zip_code
  end

  optional :preferences, suffix: "_config" do
    required :priority, type: :string
    optional :signature_required, type: :boolean, default: false
  end

  def call
    shipment = Shipment.create!(
      origin_address: origin_address,
      destination_address: destination_address,
      priority: preferences_config[:priority],
      signature_required: preferences_config[:signature_required]
    )
  end

  private

  def origin
    @origin ||= Address.find(context.origin_address_id)
  end

  def destination
    @destination ||= Address.find(context.destination_address_id)
  end
end
```

### Domain-Specific Grouping

```ruby
class ProcessPaymentTask < CMDx::Task
  # Payment-related parameters
  required :amount, prefix: "payment_", type: :big_decimal
  required :currency, prefix: "payment_", type: :string
  required :method, prefix: "payment_", type: :string

  # Customer billing parameters
  required :address, source: :billing, prefix: "billing_" do
    required :street, :city, :country
  end

  # Merchant processing parameters
  required :fee_rate, source: :processor, prefix: "processor_", type: :float
  required :timeout, source: :processor, prefix: "processor_", type: :integer

  def call
    charge = PaymentProcessor.charge(
      amount: payment_amount,
      currency: payment_currency,
      method: payment_method,
      billing_address: billing_address,
      processor_fee: payment_amount * processor_fee_rate,
      timeout: processor_timeout
    )
  end

  private

  def billing
    @billing ||= BillingAddress.find(context.billing_address_id)
  end

  def processor
    @processor ||= PaymentProcessor.for_method(payment_method)
  end
end
```

## Error Handling

> [!WARNING]
> Validation errors reference namespaced method names, not original parameter names. This affects error message interpretation and debugging.

### Validation Error Messages

```ruby
class CreateUserTask < CMDx::Task
  required :email, prefix: "user_", format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
  required :age, suffix: "_value", type: :integer, numeric: { min: 18, max: 120 }
  required :role, source: :account, prefix: "account_", inclusion: { in: %w[admin user guest] }

  def call
    User.create!(
      email: user_email,
      age: age_value,
      role: account_role
    )
  end

  private

  def account
    @account ||= Account.find(context.account_id)
  end
end

# Invalid input produces namespaced error messages
result = CreateUserTask.call(
  email: "invalid-email",
  age: "fifteen",
  account: OpenStruct.new(role: "superuser")
)

result.failed? # → true
result.metadata
# {
#   user_email format is not valid. age_value could not coerce into an integer. account_role inclusion is not valid.",
#   messages: {
#     user_email: ["format is not valid"],
#     age_value: ["could not coerce into an integer"],
#     account_role: ["inclusion is not valid"]
#   }
# }
```

### Common Namespacing Mistakes

```ruby
class ProblematicTask < CMDx::Task
  required :data, prefix: "user_"
  required :config, source: :settings, suffix: "_data"

  def call
    # ❌ WRONG: Using original parameter names in task methods
    process(data)         # NoMethodError: undefined method `data`
    apply(config)         # NoMethodError: undefined method `config`

    # ✅ CORRECT: Using namespaced method names
    process(user_data)    # Works correctly
    apply(config_data)    # Works correctly
  end

  private

  def settings
    @settings ||= AppSettings.current
  end
end

# ❌ WRONG: Using namespaced names in call arguments
ProblematicTask.call(
  user_data: { name: "John" },    # ArgumentError: unknown parameter
  config_data: { theme: "dark" }  # ArgumentError: unknown parameter
)

# ✅ CORRECT: Using original parameter names in call arguments
ProblematicTask.call(
  data: { name: "John" },         # Correct
  config: { theme: "dark" }       # Correct
)
```

### Debugging Namespaced Parameters

```ruby
class DebuggingTask < CMDx::Task
  required :id, prefix: "user_"
  required :data, source: :profile, suffix: "_payload"

  def call
    # Use introspection to understand parameter mapping
    puts "Available methods: #{methods.grep(/^(user_|.*_payload$)/)}"
    # → ["user_id", "data_payload"]

    # Access parameters using correct namespaced names
    user = User.find(user_id)
    user.update!(data_payload)
  end

  private

  def profile
    @profile ||= UserProfile.find(context.profile_id)
  end
end
```

> [!NOTE]
> When debugging namespaced parameters, remember that error messages, method introspection, and stack traces will show the namespaced method names, not the original parameter names used in task calls.

---

- **Prev:** [Parameters - Definitions](definitions.md)
- **Next:** [Parameters - Coercions](coercions.md)
