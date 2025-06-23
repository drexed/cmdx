# Parameters - Defaults

Parameter defaults provide fallback values when arguments are not provided or
resolve to `nil`. Defaults ensure tasks have sensible values for optional
parameters while maintaining flexibility for callers to override when needed.
Defaults work seamlessly with coercion, validation, and nested parameters.

## Default Value Fundamentals

Defaults are specified using the `:default` option and are applied when a
parameter value resolves to `nil`. This includes cases where optional parameters
are not provided in call arguments or when source objects return `nil` values.

### Fixed Value Defaults

The simplest defaults use fixed values that are applied consistently:

```ruby
class FixedDefaultTask < CMDx::Task

  # Simple value defaults
  required :user_id, type: :integer
  optional :priority, type: :string, default: "normal"
  optional :active, type: :boolean, default: true
  optional :retry_count, type: :integer, default: 3

  # Complex value defaults
  optional :tags, type: :array, default: []
  optional :metadata, type: :hash, default: {}
  optional :created_at, type: :datetime, default: -> { Time.current }

  def call
    user_id      #=> provided value (required)
    priority     #=> "normal" if not provided
    active       #=> true if not provided
    retry_count  #=> 3 if not provided
    tags         #=> [] if not provided
    metadata     #=> {} if not provided
    created_at   #=> current time if not provided
  end

end

# Defaults applied for missing parameters
FixedDefaultTask.call(user_id: 123)
# priority: "normal", active: true, retry_count: 3, tags: [], metadata: {}, created_at: <current time>

# Explicit values override defaults
FixedDefaultTask.call(
  user_id: 123,
  priority: "urgent",
  active: false,
  tags: ["important"]
)
```

### Callable Defaults

Use procs, lambdas, or method symbols for dynamic defaults that are evaluated
at parameter resolution time:

```ruby
class DynamicDefaultTask < CMDx::Task

  # Proc defaults
  optional :timestamp, type: :datetime, default: -> { Time.current }
  optional :request_id, type: :string, default: -> { SecureRandom.uuid }

  # Lambda defaults with context access
  optional :environment, type: :string, default: -> { Rails.env }
  optional :user_locale, type: :string, default: -> { I18n.default_locale.to_s }

  # Method symbol defaults
  optional :cache_key, type: :string, default: :generate_cache_key
  optional :expiry_time, type: :datetime, default: :calculate_expiry

  def call
    timestamp    #=> current time when parameter is accessed
    request_id   #=> unique UUID when parameter is accessed
    environment  #=> current Rails environment
    user_locale  #=> default locale as string
    cache_key    #=> result of generate_cache_key method
    expiry_time  #=> result of calculate_expiry method
  end

  private

  def generate_cache_key
    "task_#{context.user_id}_#{Time.current.to_i}"
  end

  def calculate_expiry
    1.hour.from_now
  end

end
```

### Context-Aware Defaults

Defaults can access the task context and other parameters for intelligent
fallback behavior:

```ruby
class ContextAwareDefaultTask < CMDx::Task

  required :user_id, type: :integer
  optional :account_id, type: :integer, source: :user, default: :default_account_id

  # Default based on other parameters
  optional :notification_email,
    type: :string,
    default: -> { user.email }

  # Conditional defaults
  optional :theme,
    type: :string,
    default: -> { user.premium? ? "premium" : "standard" }

  # Complex conditional logic
  optional :rate_limit,
    type: :integer,
    default: -> { determine_rate_limit }

  def call
    user_id            #=> provided value
    account_id         #=> user's default account ID
    notification_email #=> user's email address
    theme              #=> "premium" or "standard" based on user type
    rate_limit         #=> calculated based on user attributes
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def default_account_id
    user.accounts.primary.id
  end

  def determine_rate_limit
    case user.subscription_tier
    when "basic" then 100
    when "premium" then 1000
    when "enterprise" then 10000
    else 50
    end
  end

end
```

## Defaults with Type Coercion

Defaults work seamlessly with type coercion, with the default value being
subject to the same coercion rules as provided values:

```ruby
class CoercionDefaultTask < CMDx::Task

  # String defaults coerced to integers
  optional :max_retries, type: :integer, default: "5"  # => 5

  # Hash defaults coerced from JSON
  optional :config, type: :hash, default: '{"enabled": true}'  # => {"enabled" => true}

  # Array defaults from strings
  optional :tags, type: :array, default: "[]"  # => []

  # Boolean defaults from strings
  optional :active, type: :boolean, default: "true"  # => true

  # Date defaults from strings
  optional :start_date, type: :date, default: "2023-01-01"  # => Date object

  # Dynamic defaults with coercion
  optional :current_timestamp,
    type: :string,
    default: -> { Time.current.to_i }  # Integer coerced to string

  def call
    max_retries        #=> 5 (integer)
    config             #=> {"enabled" => true} (hash)
    tags               #=> [] (array)
    active             #=> true (boolean)
    start_date         #=> Date object
    current_timestamp  #=> "1640995200" (string)
  end

end
```

## Defaults with Validation

Default values are subject to the same validation rules as provided values,
ensuring consistency and catching configuration errors:

```ruby
class ValidatedDefaultTask < CMDx::Task

  # Default must pass validation
  optional :priority,
    type: :string,
    default: "normal",
    inclusion: { in: %w[low normal high urgent] }

  # Numeric default with validation
  optional :timeout,
    type: :integer,
    default: 30,
    numeric: { min: 1, max: 300 }

  # Email default with format validation
  optional :notification_email,
    type: :string,
    default: -> { "admin@#{Rails.application.config.domain}" },
    format: { with: /@/ }

  # Custom validation with default
  optional :api_key,
    type: :string,
    default: -> { generate_api_key },
    custom: { validator: ApiKeyValidator }

  def call
    priority           #=> "normal" (validated)
    timeout            #=> 30 (validated range)
    notification_email #=> admin email (validated format)
    api_key            #=> generated key (custom validated)
  end

  private

  def generate_api_key
    "key_#{SecureRandom.hex(16)}"
  end

end
```

## Nested Parameter Defaults

Defaults work with nested parameters, allowing complex default structures:

```ruby
class NestedDefaultTask < CMDx::Task

  # Parent parameter with default
  optional :shipping_config, type: :hash, default: {} do
    optional :method, type: :string, default: "standard"
    optional :expedited, type: :boolean, default: false

    optional :address, type: :hash, default: {} do
      optional :country, type: :string, default: "US"
      optional :state, type: :string, default: -> { determine_default_state }
    end
  end

  # Nested defaults with complex logic
  optional :user_preferences, type: :hash, default: -> { default_preferences } do
    optional :theme, type: :string, default: "light"
    optional :language, type: :string, default: "en"

    optional :notifications, type: :hash, default: {} do
      optional :email, type: :boolean, default: true
      optional :sms, type: :boolean, default: false
      optional :frequency, type: :string, default: "daily"
    end
  end

  def call
    # Parent defaults
    shipping_config    #=> {} if not provided
    user_preferences   #=> result of default_preferences if not provided

    # Child defaults (only if parent is provided or has default)
    method       #=> "standard"
    expedited    #=> false
    country      #=> "US"
    state        #=> result of determine_default_state

    theme        #=> "light"
    language     #=> "en"
    email        #=> true (notification email)
    sms          #=> false (notification sms)
    frequency    #=> "daily"
  end

  private

  def determine_default_state
    context.user&.address&.state || "CA"
  end

  def default_preferences
    {
      theme: context.user&.premium? ? "premium" : "light",
      language: context.user&.locale || "en"
    }
  end

end
```

## Conditional Defaults

Implement sophisticated default logic based on runtime conditions:

```ruby
class ConditionalDefaultTask < CMDx::Task

  required :user_id, type: :integer
  required :action_type, type: :string

  # Different defaults based on action type
  optional :timeout,
    type: :integer,
    default: -> { action_timeout }

  # User-specific defaults
  optional :notification_method,
    type: :string,
    default: -> { user_preferred_notification }

  # Environment-specific defaults
  optional :cache_duration,
    type: :integer,
    default: -> { Rails.env.production? ? 3600 : 60 }

  # Feature flag defaults
  optional :use_new_algorithm,
    type: :boolean,
    default: -> { FeatureFlag.enabled?(:new_algorithm, user) }

  def call
    timeout              #=> varies by action type
    notification_method  #=> user's preferred method
    cache_duration       #=> 3600 in production, 60 elsewhere
    use_new_algorithm    #=> based on feature flag
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def action_timeout
    case action_type
    when "quick" then 5
    when "standard" then 30
    when "long_running" then 300
    else 60
    end
  end

  def user_preferred_notification
    user.notification_preferences.primary_method || "email"
  end

end
```

## Default Value Caching

For expensive default calculations, consider caching strategies:

```ruby
class CachedDefaultTask < CMDx::Task

  # Cache expensive calculations
  optional :user_stats,
    type: :hash,
    default: -> { cached_user_stats }

  # Cache with expiration
  optional :market_data,
    type: :hash,
    default: -> { cached_market_data }

  def call
    user_stats   #=> cached user statistics
    market_data  #=> cached market data with expiration
  end

  private

  def cached_user_stats
    Rails.cache.fetch("user_stats_#{context.user_id}", expires_in: 1.hour) do
      calculate_user_stats
    end
  end

  def cached_market_data
    Rails.cache.fetch("market_data", expires_in: 15.minutes) do
      fetch_market_data_from_api
    end
  end

  def calculate_user_stats
    # Expensive calculation
    { orders: user.orders.count, revenue: user.orders.sum(:total) }
  end

  def fetch_market_data_from_api
    # External API call
    MarketDataService.fetch_current_data
  end

  def user
    @user ||= User.find(context.user_id)
  end

end
```

## Error Handling with Defaults

Default value calculation can fail, and these failures are handled gracefully:

```ruby
class SafeDefaultTask < CMDx::Task

  # Safe default with fallback
  optional :external_data,
    type: :hash,
    default: -> { fetch_external_data_safely }

  # Default with error handling
  optional :calculated_value,
    type: :integer,
    default: -> { safe_calculation }

  def call
    external_data    #=> external data or safe fallback
    calculated_value #=> calculated value or default fallback
  end

  private

  def fetch_external_data_safely
    ExternalService.fetch_data
  rescue ExternalService::Error => e
    Rails.logger.warn("Failed to fetch external data: #{e.message}")
    { error: "unavailable" }  # Safe fallback
  end

  def safe_calculation
    complex_calculation
  rescue => e
    Rails.logger.error("Calculation failed: #{e.message}")
    0  # Safe numeric fallback
  end

  def complex_calculation
    # Potentially failing calculation
    (context.value_a * context.value_b) / context.divisor
  end

end
```

## Best Practices

### Default Value Selection

```ruby
class BestPracticeDefaultTask < CMDx::Task

  # Use sensible defaults that work in most cases
  optional :page_size, type: :integer, default: 20
  optional :sort_order, type: :string, default: "asc"

  # Use empty collections for array/hash parameters
  optional :filters, type: :array, default: []
  optional :options, type: :hash, default: {}

  # Use boolean defaults that represent the most common case
  optional :send_notifications, type: :boolean, default: true
  optional :cache_results, type: :boolean, default: true

  # Use nil for optional references that may not exist
  optional :parent_id, type: :integer, default: nil

  def call
    # Predictable, sensible defaults available
  end

end
```

### Performance Optimization

- **Lazy evaluation**: Use procs/lambdas for expensive defaults
- **Caching**: Cache expensive default calculations
- **Simple values**: Prefer simple default values over complex calculations
- **Conditional logic**: Keep default logic simple and fast

### Error Prevention

- **Validation**: Ensure defaults pass validation rules
- **Type compatibility**: Ensure defaults are compatible with coercion types
- **Error handling**: Handle failures in dynamic default calculations
- **Testing**: Test default behavior thoroughly, especially for dynamic defaults

### Documentation and Maintenance

- **Document defaults**: Clearly document the purpose and behavior of defaults
- **Consistent patterns**: Use consistent default patterns across related parameters
- **Review regularly**: Review defaults periodically to ensure they remain appropriate
- **Version carefully**: Consider backward compatibility when changing defaults

---

- **Prev:** [Validations](https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md)
- **Next:** [Results](https://github.com/drexed/cmdx/blob/main/docs/outcomes.md)
