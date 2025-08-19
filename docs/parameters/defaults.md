# Parameters - Defaults

Parameter defaults provide fallback values when arguments are not provided or resolve to `nil`. Defaults ensure tasks have sensible values for optional parameters while maintaining flexibility for callers to override when needed.

## Table of Contents

- [TLDR](#tldr)
- [Default Fundamentals](#default-fundamentals)
- [Dynamic Defaults](#dynamic-defaults)
- [Defaults with Coercion and Validation](#defaults-with-coercion-and-validation)
- [Nested Parameter Defaults](#nested-parameter-defaults)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Fixed defaults
optional :priority, default: "normal"
optional :retries, type: :integer, default: 3
optional :tags, type: :array, default: []

# Dynamic defaults
optional :created_at, default: -> { Time.now }
optional :template, default: :determine_template

# With coercion - defaults are coerced too
optional :max_items, type: :integer, default: "50"  #=> 50

# Nested defaults
optional :config, type: :hash, default: {} do
  optional :timeout, default: 30
end
```

## Default Fundamentals

> [!NOTE]
> Defaults apply when parameters are not provided or resolve to `nil`. They work seamlessly with coercion, validation, and nested parameters.

```ruby
class ProcessOrder < CMDx::Task
  required :order_id, type: :integer

  # Fixed value defaults
  optional :priority, default: "standard"
  optional :send_email, type: :boolean, default: true
  optional :max_retries, type: :integer, default: 3
  optional :tags, type: :array, default: []
  optional :metadata, type: :hash, default: {}

  def work
    # Defaults used when parameters not provided
    process_order_with_priority(priority)     # "standard"
    send_notification if send_email           # true
    retry_failed_steps(max_retries)          # 3
  end
end

# Using defaults
ProcessOrder.execute(order_id: 123)
# priority: "standard", send_email: true, max_retries: 3

# Overriding defaults
ProcessOrder.execute(
  order_id: 123,
  priority: "urgent",
  send_email: false,
  tags: ["rush"]
)
```

## Dynamic Defaults

> [!TIP]
> Use procs, lambdas, or method symbols for dynamic defaults evaluated at runtime. Essential for timestamps, UUIDs, and context-dependent values.

```ruby
class SendNotification < CMDx::Task
  required :user_id, type: :integer
  required :message, type: :string

  # Proc defaults - evaluated when accessed
  optional :sent_at, type: :datetime, default: -> { Time.now }
  optional :tracking_id, default: -> { SecureRandom.uuid }

  # Environment-aware defaults
  optional :service, default: -> { Rails.env.production? ? "sendgrid" : "test" }

  # Method symbol defaults
  optional :template, default: :default_template
  optional :priority, default: :calculate_priority

  def work
    notification = {
      message: message,
      sent_at: sent_at,          # Current time when accessed
      tracking_id: tracking_id,  # Unique UUID when accessed
      template: template,        # Result of default_template method
      priority: priority         # Result of calculate_priority method
    }

    NotificationService.send(notification, service: service)
  end

  private

  def default_template
    user.premium? ? "premium_notification" : "standard_notification"
  end

  def calculate_priority
    user.vip? ? "high" : "normal"
  end

  def user
    @user ||= User.find(user_id)
  end
end
```

## Defaults with Coercion and Validation

> [!IMPORTANT]
> Defaults are subject to the same coercion and validation rules as provided values, ensuring consistency and catching configuration errors early.

### Coercion with Defaults

```ruby
class ConfigureService < CMDx::Task
  # String defaults coerced to target types
  optional :max_connections, type: :integer, default: "100"
  optional :config, type: :hash, default: '{"timeout": 30}'
  optional :allowed_hosts, type: :array, default: '["localhost"]'
  optional :debug_mode, type: :boolean, default: "false"

  # Dynamic defaults with coercion
  optional :session_id, type: :string, default: -> { Time.now.to_i }

  def work
    max_connections  #=> 100 (Integer from "100")
    config          #=> {"timeout" => 30} (Hash from JSON)
    allowed_hosts   #=> ["localhost"] (Array from JSON)
    debug_mode      #=> false (Boolean from "false")
    session_id      #=> "1640995200" (String from Integer)
  end
end
```

### Validation with Defaults

```ruby
class ScheduleTask < CMDx::Task
  required :task_name, type: :string

  # Default must pass validation rules
  optional :priority, default: "medium",
    inclusion: { in: %w[low medium high urgent] }

  optional :timeout, type: :integer, default: 300,
    numeric: { min: 60, max: 3600 }

  optional :retry_count, type: :integer, default: 3,
    numeric: { min: 0, max: 10 }

  def work
    # All defaults validated against their rules
    schedule_task(task_name, priority: priority, timeout: timeout)
  end
end

# Invalid default would cause validation error
# optional :priority, default: "invalid", inclusion: { in: %w[low medium high] }
#=> CMDx::ValidationError: priority invalid is not included in the list
```

## Nested Parameter Defaults

```ruby
class ProcessPayment < CMDx::Task
  required :amount, type: :float
  required :user_id, type: :integer

  # Nested structure with defaults at multiple levels
  optional :payment_config, type: :hash, default: {} do
    optional :method, default: "credit_card"
    optional :currency, default: "USD"
    optional :require_cvv, type: :boolean, default: true

    optional :billing_address, type: :hash, default: -> { user_default_address } do
      optional :country, default: "US"
      optional :state, default: -> { user_default_state }
    end

    optional :notification_settings, type: :hash, default: {} do
      optional :send_receipt, type: :boolean, default: true
      optional :send_sms, type: :boolean, default: false
    end
  end

  def work
    # Process payment with defaults applied at each level
    PaymentProcessor.charge(
      amount: amount,
      method: payment_config[:method],          # "credit_card"
      currency: payment_config[:currency],      # "USD"
      billing_address: payment_config[:billing_address],
      notifications: payment_config[:notification_settings]
    )
  end

  private

  def user
    @user ||= User.find(user_id)
  end

  def user_default_address
    user.billing_address&.to_hash || {}
  end

  def user_default_state
    user.billing_address&.state || "CA"
  end
end

# Usage with nested defaults
ProcessPayment.execute(amount: 99.99, user_id: 123)
# payment_config automatically gets:
# {
#   method: "credit_card",
#   currency: "USD",
#   require_cvv: true,
#   billing_address: { country: "US", state: "CA" },
#   notification_settings: { send_receipt: true, send_sms: false }
# }
```

## Error Handling

> [!WARNING]
> Default values that fail coercion or validation will cause task execution to fail with detailed error information.

### Validation Errors with Defaults

```ruby
class BadDefaults < CMDx::Task
  # This default will fail validation
  optional :priority, default: "invalid",
    inclusion: { in: %w[low medium high] }

  # This default will fail coercion
  optional :count, type: :integer, default: "not-a-number"

  def work
    # Won't reach here due to validation/coercion failures
  end
end

result = BadDefaults.execute
result.failed?  #=> true
result.metadata
# {
#   priority invalid is not included in the list. count could not coerce into an integer.",
#   messages: {
#     priority: ["invalid is not included in the list"],
#     count: ["could not coerce into an integer"]
#   }
# }
```

### Dynamic Default Errors

```ruby
class ProblematicDefaults < CMDx::Task
  # Method that might raise an error
  optional :config, default: :load_external_config

  # Proc that might fail
  optional :api_key, default: -> { fetch_api_key_from_vault }

  def work
    # Task logic
  end

  private

  def load_external_config
    # This might raise if external service is down
    ExternalConfigService.fetch_config
  rescue => e
    raise CMDx::Error, "Failed to load default config: #{e.message}"
  end

  def fetch_api_key_from_vault
    # This might raise if vault is unavailable
    VaultService.get_secret("api_key")
  rescue => e
    raise CMDx::Error, "Failed to fetch default API key: #{e.message}"
  end
end
```

### Nil vs Missing Parameters

```ruby
class NilHandling < CMDx::Task
  optional :status, default: "active"
  optional :tags, type: :array, default: []

  def work
    status  # Default applied based on input
    tags    # Default applied based on input
  end
end

# Missing parameters use defaults
NilHandling.execute
# status: "active", tags: []

# Explicitly nil parameters also use defaults
NilHandling.execute(status: nil, tags: nil)
# status: "active", tags: []

# Empty string is NOT nil - no default applied
NilHandling.execute(status: "", tags: "")
# status: "", tags: "" (string, not array - may cause coercion error)
```

> [!TIP]
> Defaults only apply to `nil` values. Empty strings, empty arrays, or false values are considered valid inputs and won't trigger defaults.

---

- **Prev:** [Parameters - Validations](validations.md)
- **Next:** [Callbacks](../callbacks.md)
