# Parameters - Defaults

Parameter defaults provide fallback values when arguments are not provided or
resolve to `nil`. Defaults ensure tasks have sensible values for optional
parameters while maintaining flexibility for callers to override when needed.
Defaults work seamlessly with coercion, validation, and nested parameters.

## Table of Contents

- [TLDR](#tldr)
- [Default Value Fundamentals](#default-value-fundamentals)
  - [Fixed Value Defaults](#fixed-value-defaults)
  - [Callable Defaults](#callable-defaults)
- [Defaults with Type Coercion](#defaults-with-type-coercion)
- [Defaults with Validation](#defaults-with-validation)
- [Nested Parameter Defaults](#nested-parameter-defaults)

## TLDR

- **Defaults** - Provide fallback values when parameters not provided or are `nil`
- **Fixed values** - `default: "normal"`, `default: true`, `default: []`
- **Dynamic values** - `default: -> { Time.now }`, `default: :method_name` for callable defaults
- **With coercion** - Defaults are subject to same type coercion as provided values
- **With validation** - Defaults must pass same validation rules as provided values

## Default Value Fundamentals

> [!NOTE]
> Defaults are specified using the `:default` option and are applied when a parameter value resolves to `nil`. This includes cases where optional parameters are not provided in call arguments or when source objects return `nil` values.

### Fixed Value Defaults

The simplest defaults use fixed values that are applied consistently:

```ruby
class ProcessUserOrderTask < CMDx::Task

  required :user_id, type: :integer
  optional :priority, type: :string, default: "normal"
  optional :send_confirmation, type: :boolean, default: true
  optional :max_retries, type: :integer, default: 3

  optional :notification_tags, type: :array, default: []
  optional :order_metadata, type: :hash, default: {}
  optional :created_at, type: :datetime, default: -> { Time.now }

  def call
    user_id            #=> provided value (required)
    priority           #=> "normal" if not provided
    send_confirmation  #=> true if not provided
    max_retries        #=> 3 if not provided
    notification_tags  #=> [] if not provided
    order_metadata     #=> {} if not provided
    created_at         #=> current time if not provided
  end

end

# Defaults applied for missing parameters
ProcessUserOrderTask.call(user_id: 12345)
# priority: "normal", send_confirmation: true, max_retries: 3, etc.

# Explicit values override defaults
ProcessUserOrderTask.call(
  user_id: 12345,
  priority: "urgent",
  send_confirmation: false,
  notification_tags: ["rush_order"]
)
```

### Callable Defaults

> [!TIP]
> Use procs, lambdas, or method symbols for dynamic defaults that are evaluated at parameter resolution time. This is especially useful for timestamps, UUIDs, and context-dependent values.

```ruby
class SendOrderNotificationTask < CMDx::Task

  required :order_id, type: :integer

  # Dynamic defaults using procs
  optional :sent_at, type: :datetime, default: -> { Time.now }
  optional :tracking_id, type: :string, default: -> { SecureRandom.uuid }

  # Environment-aware defaults
  optional :notification_service, type: :string, default: -> { Rails.env.production? ? "sendgrid" : "mock" }
  optional :sender_email, type: :string, default: -> { Rails.application.credentials.sender_email }

  # Method symbol defaults
  optional :template_name, type: :string, default: :determine_template
  optional :delivery_time, type: :datetime, default: :calculate_delivery_window

  def call
    sent_at              #=> current time when accessed
    tracking_id          #=> unique UUID when accessed
    notification_service #=> production or test service
    sender_email         #=> configured sender email
    template_name        #=> result of determine_template method
    delivery_time        #=> result of calculate_delivery_window method
  end

  private

  def determine_template
    order.priority == "urgent" ? "urgent_order" : "standard_order"
  end

  def calculate_delivery_window
    order.priority == "urgent" ? 15.minutes.from_now : 1.hour.from_now
  end

  def order
    @order ||= Order.find(order_id)
  end

end
```

## Defaults with Type Coercion

> [!IMPORTANT]
> Defaults work seamlessly with type coercion, with the default value being subject to the same coercion rules as provided values.

```ruby
class ConfigureOrderSettingsTask < CMDx::Task

  # String defaults coerced to integers
  optional :max_items, type: :integer, default: "50"

  # JSON string defaults coerced to hash
  optional :shipping_config, type: :hash, default: '{"carrier": "ups", "speed": "standard"}'

  # String defaults coerced to arrays
  optional :allowed_countries, type: :array, default: '["US", "CA", "UK"]'

  # String defaults coerced to booleans
  optional :require_signature, type: :boolean, default: "true"

  # String defaults coerced to dates
  optional :embargo_date, type: :date, default: "2024-01-01"

  # Dynamic defaults with coercion
  optional :order_number, type: :string, default: -> { Time.now.to_i }

  def call
    max_items         #=> 50 (integer)
    shipping_config   #=> {"carrier" => "ups", "speed" => "standard"} (hash)
    allowed_countries #=> ["US", "CA", "UK"] (array)
    require_signature #=> true (boolean)
    embargo_date      #=> Date object
    order_number      #=> "1640995200" (string from integer)
  end

end
```

## Defaults with Validation

> [!WARNING]
> Default values are subject to the same validation rules as provided values, ensuring consistency and catching configuration errors early.

```ruby
class ValidateOrderPriorityTask < CMDx::Task

  required :order_id, type: :integer

  # Default must pass inclusion validation
  optional :priority, type: :string, default: "standard",
    inclusion: { in: %w[low standard high urgent] }

  # Numeric default with range validation
  optional :processing_timeout, type: :integer, default: 300,
    numeric: { min: 60, max: 3600 }

  # Email default with format validation
  optional :escalation_email, type: :string,
    default: -> { "support@#{Rails.application.config.domain}" },
    format: { with: /@/ }

  # Custom validation with default
  optional :approval_code, type: :string, default: :generate_approval_code,
    presence: true

  def call
    priority           #=> "standard" (validated against inclusion list)
    processing_timeout #=> 300 (validated within range)
    escalation_email   #=> support email (validated format)
    approval_code      #=> generated code (custom validated)
  end

  private

  def generate_approval_code
    "APV_#{SecureRandom.hex(8).upcase}"
  end

end
```

## Nested Parameter Defaults

```ruby
class ProcessOrderShippingTask < CMDx::Task

  required :order_id, type: :integer

  # Parent parameter with default
  optional :shipping_details, type: :hash, default: {} do
    optional :carrier, type: :string, default: "fedex"
    optional :expedited, type: :boolean, default: false
    optional :insurance_required, type: :boolean, default: -> { order_value > 500 }

    optional :delivery_address, type: :hash, default: -> { customer_default_address } do
      optional :country, type: :string, default: "US"
      optional :state, type: :string, default: -> { determine_default_state }
      optional :requires_appointment, type: :boolean, default: false
    end
  end

  # Complex nested defaults
  optional :notification_preferences, type: :hash, default: -> { customer_notification_defaults } do
    optional :email_updates, type: :boolean, default: true
    optional :sms_updates, type: :boolean, default: false

    optional :delivery_window, type: :hash, default: {} do
      optional :preferred_time, type: :string, default: "anytime"
      optional :weekend_delivery, type: :boolean, default: false
    end
  end

  def call
    # Parent defaults applied when not provided
    shipping_details         #=> {} if not provided
    notification_preferences #=> customer defaults if not provided

    # Child defaults (when parent exists)
    carrier                  #=> "fedex"
    expedited                #=> false
    insurance_required       #=> true if order > $500
    country                  #=> "US"
    state                    #=> determined by logic
    email_updates            #=> true
    preferred_time           #=> "anytime"
    weekend_delivery         #=> false
  end

  private

  def order
    @order ||= Order.find(order_id)
  end

  def order_value
    order.total_amount
  end

  def customer_default_address
    order.customer.default_shipping_address&.to_hash || {}
  end

  def determine_default_state
    order.customer.billing_address&.state || "CA"
  end

  def customer_notification_defaults
    prefs = order.customer.notification_preferences
    {
      email_updates: prefs.email_enabled?,
      sms_updates: prefs.sms_enabled?
    }
  end

end
```

---

- **Prev:** [Parameters - Validations](validations.md)
- **Next:** [Callbacks](../callbacks.md)
