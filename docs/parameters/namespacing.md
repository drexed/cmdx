# Parameters - Namespacing

Parameter namespacing provides method name customization to prevent conflicts
and enable flexible parameter access patterns. When parameters share names with
existing methods or when multiple parameters from different sources have the
same name, namespacing ensures clean method resolution within tasks.

## Table of Contents

- [TLDR](#tldr)
- [Namespacing Fundamentals](#namespacing-fundamentals)
- [Fixed Value Namespacing](#fixed-value-namespacing)
- [Dynamic Source-Based Namespacing](#dynamic-source-based-namespacing)
- [Conflict Resolution](#conflict-resolution)
- [Advanced Namespacing Patterns](#advanced-namespacing-patterns)
- [Error Handling with Namespacing](#error-handling-with-namespacing)

## TLDR

- **Method naming** - Use `prefix:` and `suffix:` to customize parameter method names
- **Fixed prefixes** - `prefix: "user_"` creates `user_name` method for `name` parameter
- **Dynamic prefixes** - `prefix: true` uses source name (e.g., `context_name`)
- **Conflict resolution** - Avoid conflicts with Ruby methods or multiple same-named parameters
- **Call arguments** - Always use original parameter names, namespacing only affects method names

## Namespacing Fundamentals

> [!IMPORTANT]
> The `:prefix` and `:suffix` options modify only the generated accessor method names while preserving the original parameter names for call arguments.

This separation allows for flexible method naming without affecting the task interface.

### Fixed Value Namespacing

Use string or symbol values to add consistent prefixes or suffixes to parameter
method names:

```ruby
class CreateOrderTask < CMDx::Task

  # Fixed prefix for shipping dimensions
  required :width, prefix: "shipping_"
  required :height, prefix: "shipping_"

  # Fixed suffix for user contact info
  required :email, suffix: "_contact"
  required :phone, suffix: "_contact"

  # Combined prefix and suffix
  required :weight, prefix: "item_", suffix: "_kg"

  def call
    # Generated method names with namespacing
    shipping_width  #=> accesses width parameter
    shipping_height #=> accesses height parameter
    email_contact   #=> accesses email parameter
    phone_contact   #=> accesses phone parameter
    item_weight_kg  #=> accesses weight parameter
  end

end

# Call arguments use original parameter names
CreateOrderTask.call(
  width: 10,
  height: 20,
  email: "customer@example.com",
  phone: "555-1234",
  weight: 2.5
)
```

### Dynamic Source-Based Namespacing

Use `true` value to automatically generate prefixes or suffixes based on the
parameter source name:

```ruby
class ProcessUserRegistrationTask < CMDx::Task

  # Automatic prefix from default source (:context)
  required :user_id, prefix: true # Generates: context_user_id

  # Automatic suffix from custom source
  required :name, source: :profile, suffix: true # Generates: name_profile

  # Combined automatic namespacing
  required :email, source: :account, prefix: true, suffix: true # Generates: account_email_account

  def call
    context_user_id       #=> accesses context.user_id
    name_profile          #=> accesses profile.name
    account_email_account #=> accesses account.email
  end

  private

  def profile
    @profile ||= User.find(context.user_id).profile
  end

  def account
    @account ||= User.find(context.user_id).account
  end

end
```

> [!NOTE]
> Call arguments always use original parameter names regardless of namespacing configuration.

## Conflict Resolution

Namespacing is essential when dealing with method name conflicts or when
accessing multiple objects with similar attribute names:

### Method Name Conflicts

```ruby
class UpdateUserProfileTask < CMDx::Task

  # Avoid conflict with Ruby's built-in 'name' method
  required :name, prefix: "user_"

  # Avoid conflict with custom private methods
  required :status, suffix: "_param"

  def call
    user_name    #=> parameter value, not Ruby's Object#name
    status_param #=> parameter value, not custom status method
  end

  private

  def status
    "processing" # Custom method that would conflict without suffix
  end

end
```

### Multiple Source Disambiguation

```ruby
class GenerateInvoiceTask < CMDx::Task

  # Customer information
  required :name, source: :customer, prefix: "customer_"
  required :email, source: :customer, prefix: "customer_"

  # Company information
  required :name, source: :company, prefix: "company_"
  required :email, source: :company, prefix: "company_"

  # Order information
  required :total, source: :order, suffix: "_amount"
  required :status, source: :order, suffix: "_state"

  def call
    # Clear disambiguation of same-named attributes
    customer_name  #=> customer.name
    company_name   #=> company.name
    customer_email #=> customer.email
    company_email  #=> company.email
    total_amount   #=> order.total
    status_state   #=> order.status
  end

  private

  def customer
    @customer ||= Customer.find(context.customer_id)
  end

  def company
    @company ||= Company.find(context.company_id)
  end

  def order
    @order ||= Order.find(context.order_id)
  end

end
```

## Advanced Namespacing Patterns

### Hierarchical Namespacing

Combine namespacing with nested parameters for complex data structures:

```ruby
class CreateShipmentTask < CMDx::Task

  # Origin address with prefix
  required :origin_address, source: :shipment, prefix: "from_" do
    required :street, :city, :state, :zip
  end

  # Destination address with suffix
  required :destination_address, source: :shipment, suffix: "_to" do
    required :street, :city, :state, :zip
  end

  def call
    from_origin_address    #=> shipment.origin_address
    destination_address_to #=> shipment.destination_address

    # Nested parameters access depends on current context
    street #=> current address context street
    city   #=> current address context city
  end

  private

  def shipment
    @shipment ||= Shipment.find(context.shipment_id)
  end

end
```

### Conditional Namespacing

Apply namespacing based on runtime conditions:

```ruby
class ProcessPaymentTask < CMDx::Task

  # Different namespacing based on payment type
  required :reference_id,
    prefix: -> { context.payment_type == "credit_card" ? "card_" : "bank_" }

  def call
    # Method names determined at runtime
    if context.payment_type == "credit_card"
      card_reference_id #=> accesses reference_id parameter
    else
      bank_reference_id #=> accesses reference_id parameter
    end
  end

end
```

## Error Handling with Namespacing

```ruby
class ValidateUserDataTask < CMDx::Task

  required :email,
    prefix: "user_",
    type: :string,
    format: { with: /@/ }

  required :age,
    suffix: "_years",
    type: :integer,
    numeric: { min: 18 }

  def call
    # Access via namespaced methods
    user_email  #=> validated email
    age_years   #=> validated age
  end

end

# Invalid parameters
result = ValidateUserDataTask.call(
  email: "invalid-email",
  age: "not-a-number"
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "email format is not valid. age could not coerce into an integer.",
#     messages: {
#       user_email: ["format is not valid"],
#       age_years: ["could not coerce into an integer"]
#     }
#   }
```

---

- **Prev:** [Parameters - Definitions](definitions.md)
- **Next:** [Parameters - Coercions](coercions.md)
