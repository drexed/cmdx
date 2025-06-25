# Parameters - Namespacing

Parameter namespacing provides method name customization to prevent conflicts
and enable flexible parameter access patterns. When parameters share names with
existing methods or when multiple parameters from different sources have the
same name, namespacing ensures clean method resolution within tasks.

## Table of Contents

- [Namespacing Fundamentals](#namespacing-fundamentals)
- [Fixed Value Namespacing](#fixed-value-namespacing)
- [Dynamic Source-Based Namespacing](#dynamic-source-based-namespacing)
- [Conflict Resolution](#conflict-resolution)
- [Advanced Namespacing Patterns](#advanced-namespacing-patterns)
- [Namespacing with Validation and Coercion](#namespacing-with-validation-and-coercion)
- [Introspection and Debugging](#introspection-and-debugging)
- [Error Handling with Namespacing](#error-handling-with-namespacing)

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

## Namespacing with Validation and Coercion

> [!TIP]
> Namespacing works seamlessly with all parameter features including validation, coercion, and defaults.

```ruby
class SendNotificationTask < CMDx::Task

  # Namespaced parameters with full validation
  required :email,
    source: :recipient,
    prefix: "recipient_",
    type: :string,
    format: { with: /@/ }

  required :amount,
    source: :transaction,
    suffix: "_cents",
    type: :integer,
    numeric: { min: 0 },
    default: 0

  # Nested namespaced parameters
  required :delivery_options, prefix: "notification_" do
    required :method,
      type: :string,
      inclusion: { in: %w[email sms push] }

    optional :schedule, type: :hash do
      required :send_at, type: :time
      optional :timezone, type: :string, default: "UTC"
    end
  end

  def call
    recipient_email               #=> validated email from recipient
    amount_cents                  #=> validated integer from transaction
    notification_delivery_options #=> validated nested options

    # Access nested parameters with validation
    method   #=> validated delivery method
    send_at  #=> validated send time
    timezone #=> timezone with default
  end

  private

  def recipient
    @recipient ||= User.find(context.recipient_id)
  end

  def transaction
    @transaction ||= Transaction.find(context.transaction_id)
  end

end
```

## Introspection and Debugging

Namespaced parameters maintain full introspection capabilities:

```ruby
class DebugParametersTask < CMDx::Task

  required :email, prefix: "user_", source: :user
  required :phone, suffix: "_number"

  def call
    # Parameter introspection shows original names
    params = self.class.cmd_parameters

    params.map(&:name)        #=> [:email, :phone] (original names)
    params.map(&:method_name) #=> [:user_email, :phone_number] (generated names)

    # Method availability
    respond_to?(:email)       #=> false (original name not generated)
    respond_to?(:user_email)  #=> true (namespaced method generated)
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

end
```

## Error Handling with Namespacing

> [!WARNING]
> Parameter validation errors reference original parameter names, not the namespaced method names.

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
#       email: ["format is not valid"],    # Original parameter name
#       age: ["could not coerce into an integer"]  # Original parameter name
#     }
#   }
```

---

- **Prev:** [Parameters - Definitions](https://github.com/drexed/cmdx/blob/main/docs/parameters/definitions.md)
- **Next:** [Parameters - Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
