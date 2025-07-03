# Parameters - Defaults

Parameter defaults provide fallback values when arguments are not provided or
resolve to `nil`. Defaults ensure tasks have sensible values for optional
parameters while maintaining flexibility for callers to override when needed.
Defaults work seamlessly with coercion, validation, and nested parameters.

## Table of Contents

- [Default Value Fundamentals](#default-value-fundamentals)
  - [Fixed Value Defaults](#fixed-value-defaults)
  - [Callable Defaults](#callable-defaults)
  - [Context-Aware Defaults](#context-aware-defaults)
- [Defaults with Type Coercion](#defaults-with-type-coercion)
- [Defaults with Validation](#defaults-with-validation)
- [Nested Parameter Defaults](#nested-parameter-defaults)
- [Conditional Defaults](#conditional-defaults)
- [Default Value Caching](#default-value-caching)
- [Error Handling with Defaults](#error-handling-with-defaults)

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

### Context-Aware Defaults

```ruby
class ProcessUserPaymentTask < CMDx::Task

  required :user_id, type: :integer
  required :amount, type: :float

  optional :payment_method_id, type: :integer, default: :default_payment_method
  optional :billing_email, type: :string, default: -> { user.email }
  optional :currency, type: :string, default: -> { user.preferred_currency || "USD" }
  optional :processing_fee, type: :float, default: -> { calculate_processing_fee }

  def call
    payment_method_id #=> user's default payment method
    billing_email     #=> user's email address
    currency          #=> user's preferred currency or USD
    processing_fee    #=> calculated based on amount and user tier
  end

  private

  def user
    @user ||= User.find(user_id)
  end

  def default_payment_method
    user.payment_methods.primary&.id || user.payment_methods.first&.id
  end

  def calculate_processing_fee
    base_fee = amount * 0.029
    user.premium_member? ? base_fee * 0.5 : base_fee
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
    custom: { validator: ApprovalCodeValidator }

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

## Conditional Defaults

```ruby
class ProcessOrderPaymentTask < CMDx::Task

  required :user_id, type: :integer
  required :order_type, type: :string
  required :amount, type: :float

  # Different timeouts based on order type
  optional :payment_timeout, type: :integer, default: -> { determine_payment_timeout }

  # User tier-specific defaults
  optional :processing_priority, type: :string, default: -> { user_processing_priority }

  # Environment-specific defaults
  optional :fraud_check_level, type: :string,
    default: -> { Rails.env.production? ? "strict" : "relaxed" }

  # Feature flag-based defaults
  optional :use_instant_processing, type: :boolean,
    default: -> { FeatureFlag.enabled?(:instant_processing, user) }

  # Amount-based conditional defaults
  optional :requires_manual_review, type: :boolean,
    default: -> { amount > manual_review_threshold }

  def call
    payment_timeout        #=> varies by order type
    processing_priority    #=> based on user tier
    fraud_check_level      #=> environment-dependent
    use_instant_processing #=> feature flag controlled
    requires_manual_review #=> amount-dependent
  end

  private

  def user
    @user ||= User.find(user_id)
  end

  def determine_payment_timeout
    case order_type
    when "express" then 30
    when "standard" then 300
    when "subscription" then 600
    else 180
    end
  end

  def user_processing_priority
    case user.membership_tier
    when "premium" then "high"
    when "gold" then "highest"
    else "normal"
    end
  end

  def manual_review_threshold
    user.trusted_customer? ? 10000 : 1000
  end

end
```

## Default Value Caching

> [!TIP]
> For expensive default calculations, implement caching strategies to improve performance while maintaining accuracy.

```ruby
class GenerateOrderReportTask < CMDx::Task

  required :user_id, type: :integer

  # Cache expensive user analytics
  optional :user_analytics, type: :hash, default: -> { cached_user_analytics }

  # Cache market data with shorter expiration
  optional :pricing_data, type: :hash, default: -> { cached_pricing_data }

  # Cache user preferences
  optional :report_settings, type: :hash, default: -> { cached_user_report_settings }

  def call
    user_analytics  #=> cached user analytics (1 hour TTL)
    pricing_data    #=> cached pricing data (15 minutes TTL)
    report_settings #=> cached user settings (24 hours TTL)
  end

  private

  def cached_user_analytics
    Rails.cache.fetch("user_analytics_#{user_id}", expires_in: 1.hour) do
      calculate_user_analytics
    end
  end

  def cached_pricing_data
    Rails.cache.fetch("pricing_data", expires_in: 15.minutes) do
      PricingService.fetch_current_rates
    end
  end

  def cached_user_report_settings
    Rails.cache.fetch("report_settings_#{user_id}", expires_in: 24.hours) do
      user.report_preferences.to_hash
    end
  end

  def calculate_user_analytics
    {
      total_orders: user.orders.count,
      lifetime_value: user.orders.sum(:total),
      avg_order_value: user.orders.average(:total),
      last_order_date: user.orders.maximum(:created_at)
    }
  end

  def user
    @user ||= User.find(user_id)
  end

end
```

## Error Handling with Defaults

> [!WARNING]
> Default value calculation can fail. Implement proper error handling to provide safe fallbacks and maintain task reliability.

```ruby
class ProcessOrderAnalyticsTask < CMDx::Task

  required :order_id, type: :integer

  # Safe external data fetching with fallback
  optional :market_trends, type: :hash, default: -> { fetch_market_trends_safely }

  # Safe calculation with error handling
  optional :predicted_delivery, type: :datetime, default: -> { calculate_delivery_safely }

  # Database query with fallback
  optional :similar_orders, type: :array, default: -> { find_similar_orders_safely }

  def call
    market_trends      #=> market data or safe fallback
    predicted_delivery #=> calculated delivery or default estimate
    similar_orders     #=> similar orders or empty array
  end

  private

  def order
    @order ||= Order.find(order_id)
  end

  def fetch_market_trends_safely
    MarketAnalyticsService.fetch_trends(order.category)
  rescue MarketAnalyticsService::Error, Net::TimeoutError => e
    Rails.logger.warn("Failed to fetch market trends: #{e.message}")
    { trend: "stable", confidence: "low" }
  end

  def calculate_delivery_safely
    DeliveryEstimator.calculate(order)
  rescue DeliveryEstimator::Error => e
    Rails.logger.error("Delivery calculation failed: #{e.message}")
    # Safe fallback based on shipping method
    case order.shipping_method
    when "express" then 2.days.from_now
    when "standard" then 5.days.from_now
    else 7.days.from_now
    end
  end

  def find_similar_orders_safely
    Order.similar_to(order).limit(10).to_a
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Similar orders query failed: #{e.message}")
    []
  end

end
```

---

- **Prev:** [Validations](validations.md)
- **Next:** [Results](../outcomes.md)
