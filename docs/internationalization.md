# Internationalization (i18n)

CMDx provides comprehensive internationalization support for all error messages, parameter validation failures, coercion errors, and fault messages. All user-facing text is automatically localized based on the current `I18n.locale`, ensuring your applications can serve global audiences with native-language error reporting.

## Table of Contents

- [TLDR](#tldr)
- [Available Locales](#available-locales)
- [Configuration](#configuration)
- [Fault Messages](#fault-messages)
- [Parameter Messages](#parameter-messages)
- [Coercion Messages](#coercion-messages)
- [Validation Messages](#validation-messages)
- [Custom Message Overrides](#custom-message-overrides)
- [Error Handling and Debugging](#error-handling-and-debugging)

## TLDR

```ruby
# Automatic localization based on I18n.locale
I18n.locale = :es
result = CreateUser.execute(email: "invalid", age: "too-young")
result.metadata[:messages][:email] #=> ["formato inválido"]

# 24 built-in languages with complete coverage
# Parameter-specific overrides available
# Covers coercion, validation, and fault messages
```

> [!NOTE]
> CMDx automatically localizes all error messages based on your application's `I18n.locale` setting. No additional configuration is required for basic usage.

## Available Locales

CMDx includes built-in translations for 24 major world languages, covering both Western and Eastern language families:

| Language | Locale | Language | Locale | Language | Locale |
|----------|--------|----------|--------|----------|--------|
| English | `:en` | Russian | `:ru` | Arabic | `:ar` |
| Spanish | `:es` | Korean | `:ko` | Dutch | `:nl` |
| French | `:fr` | Hindi | `:hi` | Swedish | `:sv` |
| German | `:de` | Polish | `:pl` | Norwegian | `:no` |
| Portuguese | `:pt` | Turkish | `:tr` | Finnish | `:fi` |
| Italian | `:it` | Danish | `:da` | Greek | `:el` |
| Japanese | `:ja` | Czech | `:cs` | Hebrew | `:he` |
| Chinese | `:zh` | Thai | `:th` | Vietnamese | `:vi` |

> [!TIP]
> All locales provide complete coverage for every error message type, including complex nested parameter validation errors and multi-type coercion failures.

## Configuration

### Basic Setup

```ruby
# In Rails applications (config/application.rb)
config.i18n.default_locale = :en
config.i18n.available_locales = [:en, :es, :fr, :de]

# Runtime locale switching
class ApiController < ApplicationController
  before_action :set_locale

  private

  def set_locale
    I18n.locale = params[:locale] || request.headers['Accept-Language']&.scan(/^[a-z]{2}/)&.first || :en
  end
end
```

### Per-Request Localization

```ruby
class ProcessOrder < CMDx::Task
  required :amount, type: :float
  required :customer_email, format: { with: /@/ }

  def work
    # Task logic runs with current I18n.locale
    ChargeCustomer.execute(amount: amount, email: customer_email)
  end
end

# Different locales produce localized errors
I18n.with_locale(:fr) do
  result = ProcessOrder.execute(amount: "invalid", customer_email: "bad-email")
  result.metadata[:messages][:amount] #=> ["impossible de contraindre en float"]
end
```

## Fault Messages

> [!IMPORTANT]
> Fault messages from `fail!` and `skip!` methods are automatically localized when no explicit reason is provided.

### Default Fault Localization

```ruby
class ProcessPayment < CMDx::Task
  required :payment_method, inclusion: { in: %w[card paypal bank] }
  required :amount, type: :float

  def work
    if payment_declined?
      fail!  # Uses localized default message
    end

    if amount < minimum_charge
      skip!  # Uses localized default message
    end

    charge_payment
  end

  private

  def payment_declined?
    # Payment gateway logic
    rand > 0.8
  end

  def minimum_charge
    5.00
  end
end

# English
I18n.locale = :en
result = ProcessPayment.execute(payment_method: "card", amount: 99.99)
result.reason #=> "no reason given"

# Spanish
I18n.locale = :es
result = ProcessPayment.execute(payment_method: "card", amount: 99.99)
result.reason #=> "no se proporcionó razón"

# Japanese
I18n.locale = :ja
result = ProcessPayment.execute(payment_method: "card", amount: 99.99)
result.reason #=> "理由が提供されませんでした"
```

### Custom Fault Messages

```ruby
class ProcessRefund < CMDx::Task
  required :order_id, type: :integer
  required :reason, presence: true

  def work
    order = find_order(order_id)

    # Custom messages override locale defaults
    fail!("Payment gateway unavailable") if gateway_down?
    skip!("Refund already processed") if order.refunded?

    process_refund(order)
  end
end
```

## Parameter Messages

> [!WARNING]
> Parameter errors include both missing required parameters and undefined source method delegates, with full internationalization support.

### Required Parameter Errors

```ruby
class CreateUserAccount < CMDx::Task
  required :email, format: { with: /@/ }
  required :password, length: { min: 8 }
  required :age, type: :integer, numeric: { min: 18 }

  optional :profile_image, source: :nonexistent_upload_method
  optional :referral_code, source: :missing_referral_source

  def work
    User.create!(email: email, password: password, age: age)
  end
end

# Missing required parameters
I18n.locale = :en
result = CreateUserAccount.execute({})
result.metadata[:messages]
# {
#   email: ["is a required parameter"],
#   password: ["is a required parameter"],
#   age: ["is a required parameter"]
# }

# German localization
I18n.locale = :de
result = CreateUserAccount.execute({})
result.metadata[:messages]
# {
#   email: ["ist ein erforderlicher Parameter"],
#   password: ["ist ein erforderlicher Parameter"],
#   age: ["ist ein erforderlicher Parameter"]
# }
```

### Source Method Errors

```ruby
# Undefined source method delegation
I18n.locale = :en
result = CreateUserAccount.execute(
  email: "user@example.com",
  password: "securepass",
  age: 25
)
result.metadata[:messages]
# {
#   profile_image: ["delegates to undefined method nonexistent_upload_method"],
#   referral_code: ["delegates to undefined method missing_referral_source"]
# }

# French localization
I18n.locale = :fr
result = CreateUserAccount.execute(
  email: "user@example.com",
  password: "securepass",
  age: 25
)
result.metadata[:messages]
# {
#   profile_image: ["délègue à la méthode non définie nonexistent_upload_method"],
#   referral_code: ["délègue à la méthode non définie missing_referral_source"]
# }
```

## Coercion Messages

> [!NOTE]
> Type conversion failures provide detailed, localized error messages that specify the attempted type(s) and input value context.

### Single Type Coercion Errors

```ruby
class ProcessInventory < CMDx::Task
  required :product_id, type: :integer
  required :price, type: :float
  required :in_stock, type: :boolean
  required :categories, type: :array
  required :metadata, type: :hash

  def work
    # Task implementation
  end
end

# English coercion errors
I18n.locale = :en
result = ProcessInventory.execute(
  product_id: "not-a-number",
  price: "invalid-price",
  in_stock: "maybe",
  categories: "[invalid json",
  metadata: "not-a-hash"
)

result.metadata[:messages]
# {
#   product_id: ["could not coerce into an integer"],
#   price: ["could not coerce into a float"],
#   in_stock: ["could not coerce into a boolean"],
#   categories: ["could not coerce into an array"],
#   metadata: ["could not coerce into a hash"]
# }

# Spanish coercion errors
I18n.locale = :es
result = ProcessInventory.execute(
  product_id: "not-a-number",
  price: "invalid-price"
)

result.metadata[:messages]
# {
#   product_id: ["no se pudo coaccionar a un integer"],
#   price: ["no se pudo coaccionar a un float"]
# }
```

### Multiple Type Coercion Errors

```ruby
class ProcessFlexibleData < CMDx::Task
  required :amount, type: [:float, :big_decimal, :integer]
  required :identifier, type: [:integer, :string]
  required :timestamp, type: [:datetime, :date, :time]

  def work
    # Task implementation
  end
end

# Multiple type failure messages
I18n.locale = :en
result = ProcessFlexibleData.execute(
  amount: "definitely-not-numeric",
  identifier: nil,
  timestamp: "not-a-date"
)

result.metadata[:messages]
# {
#   amount: ["could not coerce into one of: float, big_decimal, integer"],
#   identifier: ["could not coerce into one of: integer, string"],
#   timestamp: ["could not coerce into one of: datetime, date, time"]
# }

# Chinese localization
I18n.locale = :zh
result = ProcessFlexibleData.execute(amount: "invalid")
result.metadata[:messages][:amount] #=> ["无法强制转换为以下类型之一：float、big_decimal、integer"]
```

### Nested Parameter Coercion

```ruby
class ProcessOrder < CMDx::Task
  required :order, type: :hash do
    required :id, type: :integer
    required :total, type: :float

    required :customer, type: :hash do
      required :id, type: :integer
      required :active, type: :boolean
    end
  end

  def work
    # Task implementation
  end
end

# Nested coercion errors with full path context
result = ProcessOrder.execute(
  order: {
    id: "not-a-number",
    total: "invalid-amount",
    customer: {
      id: "bad-id",
      active: "maybe"
    }
  }
)

result.metadata[:messages]
# {
#   "order.id": ["could not coerce into an integer"],
#   "order.total": ["could not coerce into a float"],
#   "order.customer.id": ["could not coerce into an integer"],
#   "order.customer.active": ["could not coerce into a boolean"]
# }
```

## Validation Messages

> [!TIP]
> All built-in validators provide comprehensive internationalization support, including contextual information for complex validation rules.

### Format Validation

```ruby
class CreateUser < CMDx::Task
  required :email, format: { with: /@/, message: nil }  # Use default i18n
  required :phone, format: { with: /\A\+?[\d\s-()]+\z/ }
  required :username, format: { with: /\A[a-zA-Z0-9_]+\z/ }

  def work
    User.create!(email: email, phone: phone, username: username)
  end
end

# English format errors
I18n.locale = :en
result = CreateUser.execute(
  email: "not-an-email",
  phone: "invalid!phone",
  username: "bad@username"
)

result.metadata[:messages]
# {
#   email: ["is an invalid format"],
#   phone: ["is an invalid format"],
#   username: ["is an invalid format"]
# }

# Japanese format errors
I18n.locale = :ja
result = CreateUser.execute(email: "invalid", phone: "bad")
result.metadata[:messages]
# {
#   email: ["無効な形式です"],
#   phone: ["無効な形式です"]
# }
```

### Numeric Validation

```ruby
class ConfigureService < CMDx::Task
  required :port, numeric: { min: 1024, max: 65535 }
  required :timeout, numeric: { greater_than: 0, less_than: 300 }
  required :retry_count, numeric: { min: 1, max: 10 }

  def work
    # Service configuration
  end
end

# English numeric errors
I18n.locale = :en
result = ConfigureService.execute(
  port: 80,           # Below minimum
  timeout: 500,       # Above maximum
  retry_count: 0      # Below minimum
)

result.metadata[:messages]
# {
#   port: ["must be greater than or equal to 1024"],
#   timeout: ["must be less than 300"],
#   retry_count: ["must be greater than or equal to 1"]
# }

# German numeric errors
I18n.locale = :de
result = ConfigureService.execute(port: 80, timeout: 500)
result.metadata[:messages]
# {
#   port: ["muss größer oder gleich 1024 sein"],
#   timeout: ["muss kleiner als 300 sein"]
# }
```

### Inclusion and Exclusion

```ruby
class ProcessSubscription < CMDx::Task
  required :plan, inclusion: { in: %w[basic premium enterprise] }
  required :billing_cycle, inclusion: { in: %w[monthly yearly] }
  required :username, exclusion: { from: %w[admin root system] }

  def work
    # Subscription processing
  end
end

# English inclusion/exclusion errors
I18n.locale = :en
result = ProcessSubscription.execute(
  plan: "invalid-plan",
  billing_cycle: "weekly",
  username: "admin"
)

result.metadata[:messages]
# {
#   plan: ["is not included in the list"],
#   billing_cycle: ["is not included in the list"],
#   username: ["is reserved"]
# }

# French inclusion/exclusion errors
I18n.locale = :fr
result = ProcessSubscription.execute(plan: "invalid", username: "root")
result.metadata[:messages]
# {
#   plan: ["n'est pas inclus dans la liste"],
#   username: ["est réservé"]
# }
```

### Length Validation

```ruby
class CreatePost < CMDx::Task
  required :title, length: { min: 5, max: 100 }
  required :content, length: { min: 50 }
  required :tags, length: { max: 10 }

  def work
    Post.create!(title: title, content: content, tags: tags)
  end
end

# English length errors
I18n.locale = :en
result = CreatePost.execute(
  title: "Hi",                    # Too short
  content: "Brief content",       # Too short
  tags: (1..15).to_a             # Too many
)

result.metadata[:messages]
# {
#   title: ["is too short (minimum is 5 characters)"],
#   content: ["is too short (minimum is 50 characters)"],
#   tags: ["is too long (maximum is 10 characters)"]
# }

# Russian length errors
I18n.locale = :ru
result = CreatePost.execute(title: "Hi", content: "Short")
result.metadata[:messages]
# {
#   title: ["слишком короткий (минимум 5 символов)"],
#   content: ["слишком короткий (минимум 50 символов)"]
# }
```

## Custom Message Overrides

> [!IMPORTANT]
> Parameter-specific custom messages always take precedence over locale defaults, allowing fine-grained control while maintaining i18n support.

### Override Examples

```ruby
class RegisterAccount < CMDx::Task
  required :email,
    format: { with: /@/, message: "Please provide a valid email address" }

  required :password,
    length: { min: 8, message: "Password must be at least 8 characters" }

  required :age,
    numeric: { min: 18, message: "You must be 18 or older to register" }

  def work
    # Custom messages override i18n, regardless of locale
  end
end

# Custom messages ignore locale settings
I18n.locale = :es
result = RegisterAccount.execute(
  email: "invalid",
  password: "short",
  age: 16
)

result.metadata[:messages]
# {
#   email: ["Please provide a valid email address"],      # Custom override
#   password: ["Password must be at least 8 characters"], # Custom override
#   age: ["You must be 18 or older to register"]         # Custom override
# }
```

### Conditional Overrides

```ruby
class ProcessPayment < CMDx::Task
  required :amount, type: :float, numeric: { min: 0.01 }

  # Conditional message based on context
  def validate_amount
    if context[:currency] == "USD" && amount < 0.50
      add_error(:amount, "USD payments must be at least $0.50")
    elsif context[:currency] == "EUR" && amount < 0.01
      add_error(:amount, "EUR payments must be at least €0.01")
    end
  end

  def work
    validate_amount
    # Payment processing
  end
end
```

## Error Handling and Debugging

> [!WARNING]
> When debugging i18n issues, check locale availability, fallback behavior, and message key resolution to identify configuration problems.

### Debugging Missing Translations

```ruby
# Enable translation debugging
I18n.exception_handler = lambda do |exception, locale, key, options|
  Rails.logger.warn "Missing translation: #{locale}.#{key}"
  "translation missing: #{locale}.#{key}"
end

class Debugging < CMDx::Task
  required :test_param, type: :integer

  def work
    # Intentionally trigger coercion error for debugging
  end
end

# Test with unsupported locale
I18n.locale = :unsupported_locale
result = Debugging.execute(test_param: "invalid")
# Logs: "Missing translation: unsupported_locale.cmdx.errors.coercion.integer"
```

### Fallback Configuration

```ruby
# Configure fallback behavior in Rails
I18n.fallbacks = { es: [:es, :en], fr: [:fr, :en] }

class TestLocalization < CMDx::Task
  required :value, type: :integer

  def work
    # Task logic
  end
end

# Test fallback behavior
I18n.locale = :es  # Falls back to :en if Spanish translation missing
result = TestLocalization.execute(value: "invalid")
# Uses English if Spanish translation unavailable
```

### Error Message Analysis

```ruby
class AnalyzeErrors < CMDx::Task
  required :data, type: :hash do
    required :id, type: :integer
    required :nested, type: :hash do
      required :value, type: :float
    end
  end

  def work
    # Complex nested structure for testing
  end
end

# Comprehensive error analysis
result = AnalyzeErrors.execute(
  data: {
    id: "not-integer",
    nested: {
      value: "not-float"
    }
  }
)

# Analyze error structure
puts "Failed: #{result.failed?}"
puts "Error count: #{result.metadata[:messages].count}"
puts "Nested errors present: #{result.metadata[:messages].keys.any? { |k| k.include?('.') }}"

result.metadata[:messages].each do |param, errors|
  puts "#{param}: #{errors.join(', ')}"
end
# Output shows full parameter path context for nested errors
```

---

- **Prev:** [Logging](logging.md)
- **Next:** [Testing](testing.md)
