---
date: 2026-02-04
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-attributes
---

# Mastering CMDx Attributes: Your Task's Contract with the World

Attributes in CMDx are deceptively simple. You define what data your task needs, and the framework handles the rest—coercion, validation, defaults, the works. But there's real depth here. After building dozens of production systems with CMDx, I've found that well-designed attributes are the difference between tasks that "just work" and tasks that fight you at every turn.

Let me show you what I mean.

<!-- more -->

## Starting Simple: Required vs Optional

Every task starts with a question: what data do I need? Let's build a simple user registration task:

```ruby
class RegisterUser < CMDx::Task
  required :email
  required :password
  optional :name

  def work
    user = User.create!(
      email: email,
      password: password,
      name: name
    )
    context.user = user
  end
end
```

The `required` and `optional` helpers make intent crystal clear. When you call this task:

```ruby
# This works
result = RegisterUser.execute(email: "alice@example.com", password: "secret123")

# This fails immediately
result = RegisterUser.execute(password: "secret123")
result.failed?           # => true
result.metadata[:errors] # => { messages: { email: ["is required"] } }
```

No exceptions to catch, no mystery failures buried in a stack trace. The task tells you exactly what went wrong.

## How Attributes Become Methods

You might have noticed something in that example: I'm calling `email` and `password` directly, not `context.email` or `@email`. That's because **each attribute definition creates an instance method on your task** (Ruby FTW 🏆).

When you write:

```ruby
class RegisterUser < CMDx::Task
  required :email
  required :password
  optional :name
end
```

CMDx generates something equivalent to:

```ruby
def email
  attributes[:email]
end

def password
  attributes[:password]
end

def name
  attributes[:name]
end
```

These methods return the fully processed value—sourced, coerced, transformed, and validated. The `attributes` hash is where CMDx stores all your processed attribute values, separate from the raw `context`.

This design gives you several benefits:

1. **Clean code** — `email` reads better than `context.email` or `context[:email]`
2. **Encapsulation** — The method returns the processed value, not the raw input
3. **IDE support** — Your editor can autocomplete and navigate to attribute definitions
4. **Conflict detection** — CMDx raises an error if an attribute would shadow an existing method

That last point is important. If you try this:

```ruby
class BadTask < CMDx::Task
  required :context  # Conflicts with CMDx::Task#context
end
```

You'll get a clear error:

```
The method :context is already defined on the BadTask task.
This may be due to conflicts with one of the task's user defined or internal methods/attributes.

Use :as, :prefix, and/or :suffix attribute options to avoid conflicts with existing methods.
```

We'll cover those naming options later, but the key insight is: attributes aren't just data declarations—they're method definitions.

## Type Coercion: Let the Framework Do the Heavy Lifting

Here's where things get interesting. Real-world data is messy. Form submissions send everything as strings. JSON payloads might have numbers where you expect integers. CMDx handles this automatically:

```ruby
class ProcessPayment < CMDx::Task
  required :amount, type: :big_decimal
  required :currency, type: :symbol
  optional :metadata, type: :hash
  optional :processed_at, type: :datetime

  def work
    amount       # => BigDecimal("99.99") (was "99.99")
    currency     # => :usd (was "usd")
    metadata     # => {"source" => "web"} (was '{"source":"web"}')
    processed_at # => DateTime object (was "2025-01-07T10:30:00Z")
  end
end

ProcessPayment.execute(
  amount: "99.99",
  currency: "usd",
  metadata: '{"source":"web"}',
  processed_at: "2025-01-07T10:30:00Z"
)
```

The built-in coercions cover most cases:

| Type | What it does |
|------|--------------|
| `:integer` | Handles strings, hex (`0xFF`), octal (`077`) |
| `:float` | Parses numeric strings |
| `:big_decimal` | High-precision decimals |
| `:boolean` | Understands "yes"/"no", "true"/"false", 1/0 |
| `:symbol` | Converts strings to symbols |
| `:array` | Wraps single values, parses JSON arrays |
| `:hash` | Parses JSON objects |
| `:date` / `:datetime` / `:time` | Flexible date parsing |

When data can come in multiple formats, specify fallbacks:

```ruby
class ImportRecord < CMDx::Task
  # Try rational first, fall back to big_decimal
  required :value, type: [:rational, :big_decimal]
end
```

CMDx attempts each type in order until one succeeds.

## Validation: Declarative Data Integrity

Coercion gets your data into the right shape. Validation ensures it makes sense:

```ruby
class CreateProject < CMDx::Task
  required :name,
    presence: true,
    length: { minimum: 3, maximum: 100 }

  required :budget,
    type: :big_decimal,
    numeric: { min: 1000, max: 1_000_000 }

  required :priority,
    type: :symbol,
    inclusion: { in: [:low, :medium, :high, :critical] }

  optional :contact_email,
    format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    Project.create!(
      name: name,
      budget: budget,
      priority: priority,
      contact_email: contact_email
    )
  end
end
```

Validation happens *after* coercion, so you're validating the final value, not the raw input. This is exactly what you want—validate `BigDecimal("1000")`, not the string `"1000"`.

The error messages are structured and actionable:

```ruby
result = CreateProject.execute(
  name: "AB",
  budget: "500",
  priority: "urgent",
  contact_email: "not-an-email"
)

result.metadata[:errors]
# => {
#      full_message: "name is too short (minimum is 3 characters). budget must be at least 1000. priority is not included in the list. contact_email is invalid.",
#      messages: {
#        name: ["is too short (minimum is 3 characters)"],
#        budget: ["must be at least 1000"],
#        priority: ["is not included in the list"],
#        contact_email: ["is invalid"]
#      }
#    }
```

## Defaults: Smart Fallbacks

Sometimes attributes should have sensible defaults. Static values work great:

```ruby
class ScheduleBackup < CMDx::Task
  required :database_name
  optional :retention_days, default: 7
  optional :compression, default: "gzip"
  optional :notify, default: true

  def work
    retention_days # => 7 (when not provided)
    compression    # => "gzip"
    notify         # => true
  end
end
```

But often defaults need context. Use procs for dynamic defaults:

```ruby
class GenerateReport < CMDx::Task
  required :user_id
  optional :timezone, default: -> { Current.user&.timezone || "UTC" }
  optional :format, default: proc { context.user_id.to_s.start_with?("admin") ? "detailed" : "summary" }

  def work
    # timezone and format resolved at execution time
  end
end
```

Or reference a method for complex logic:

```ruby
class ProcessAnalytics < CMDx::Task
  required :account_id
  optional :granularity, default: :default_granularity

  def work
    granularity # => "hourly" for premium, "daily" for free
  end

  private

  def default_granularity
    account.premium? ? "hourly" : "daily"
  end

  def account
    @account ||= Account.find(context.account_id)
  end
end
```

Defaults are coerced and validated like any other value:

```ruby
class ScheduleBackup < CMDx::Task
  # Default "7" gets coerced to integer, then validated
  optional :retention_days,
    default: "7",
    type: :integer,
    numeric: { min: 1, max: 30 }
end
```

## Transformations: Clean Data Before Validation

Sometimes you need to normalize data before validating it. Transformations run after coercion but before validation:

```ruby
class ProcessContact < CMDx::Task
  required :email,
    transform: ->(v) { v.to_s.downcase.strip },
    format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  required :phone,
    transform: ->(v) { v.gsub(/\D/, "") },  # Strip non-digits
    length: { is: 10 }

  optional :preferences,
    type: :hash,
    transform: :compact_blank  # Remove empty values

  def work
    email       # => "alice@example.com" (was "  ALICE@Example.COM  ")
    phone       # => "5551234567" (was "(555) 123-4567")
    preferences # => { theme: "dark" } (was { theme: "dark", other: "" })
  end
end
```

For reusable transformations, use a class:

```ruby
class EmailNormalizer
  def self.call(value)
    value.to_s.downcase.strip.gsub(/\s+/, "")
  end
end

class ProcessContact < CMDx::Task
  required :email, transform: EmailNormalizer
end
```

## Sources: Reading from Anywhere

By default, attributes read from the context. But sometimes your data lives elsewhere:

```ruby
class UpdateUserProfile < CMDx::Task
  required :user_id

  # Read from a method that returns an object
  required :current_plan, source: :user
  required :email, source: :user

  # Read from a lambda
  optional :feature_flags, source: -> { Current.feature_flags }

  # Read from a class
  optional :server_config, source: ConfigResolver

  def work
    current_plan  # => user.current_plan
    email         # => user.email
    feature_flags # => Current.feature_flags[:user_id]
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end
end
```

This is powerful for building tasks that aggregate data from multiple sources without cluttering your context.

## Nested Attributes: Handling Complex Structures

Real APIs send nested data. CMDx handles this elegantly:

```ruby
class ConfigureServer < CMDx::Task
  required :server_id

  required :network do
    required :hostname, format: /\A[a-z0-9\-\.]+\z/i
    required :port, type: :integer, numeric: { min: 1, max: 65535 }
    optional :protocol, default: "https", inclusion: { in: %w[http https] }
  end

  optional :ssl do
    required :certificate_path, presence: true
    required :private_key_path, presence: true
    optional :passphrase
  end

  optional :monitoring do
    required :provider, inclusion: { in: %w[datadog newrelic prometheus] }

    optional :alerting do
      required :threshold, type: :integer, numeric: { min: 1, max: 100 }
      optional :channel, default: "slack"
    end
  end

  def work
    # Access nested values directly
    hostname  # => "api.example.com"
    port      # => 443
    protocol  # => "https"
    threshold # => 85 (from monitoring.alerting.threshold)
    channel   # => "slack"

    # Or access the whole structure
    network   # => { hostname: "api.example.com", port: 443, protocol: "https" }
  end
end
```

The key insight: **child requirements only apply when the parent is provided**. If `ssl` isn't passed, `certificate_path` and `private_key_path` aren't required. But if you pass `ssl: {}`, they become required.

```ruby
# Valid - ssl is optional, so no ssl config needed
ConfigureServer.execute(
  server_id: "srv-001",
  network: { hostname: "api.example.com", port: 443 }
)

# Invalid - ssl provided but missing required children
ConfigureServer.execute(
  server_id: "srv-001",
  network: { hostname: "api.example.com", port: 443 },
  ssl: {}  # Missing certificate_path and private_key_path!
)
```

## Naming: Avoiding Conflicts

Sometimes attribute names conflict with existing methods. Use naming options to work around this:

```ruby
class ProcessData < CMDx::Task
  # Conflicts with Object#class
  required :class, as: :category

  # Add context for clarity
  required :template, prefix: true  # => context_template
  required :version, suffix: "_tag" # => version_tag

  def work
    category         # => "premium"
    context_template # => "monthly_report"
    version_tag      # => "v2.1.0"
  end
end

# Still pass original names
ProcessData.execute(class: "premium", template: "monthly_report", version: "v2.1.0")
```

## Conditional Requirements

Sometimes an attribute is only required under certain conditions:

```ruby
class PublishContent < CMDx::Task
  required :title
  required :content
  required :status, inclusion: { in: %w[draft published scheduled] }

  # Only required when scheduled
  required :publish_at, type: :datetime, if: :scheduled?

  # Only required for published content
  required :author_id, unless: proc { status == "draft" }

  def work
    # ...
  end

  private

  def scheduled?
    context.status == "scheduled"
  end
end
```

When the condition is false, the attribute becomes optional. All other features—coercion, validation, defaults—still apply.

## Custom Coercions and Validators

For domain-specific types, register your own coercions:

```ruby
class GeoCoercion
  def self.call(value, options = {})
    case value
    when Array then Geo::Point.new(*value)
    when String then Geo::Point.parse(value)
    when Geo::Point then value
    else raise CMDx::CoercionError, "cannot convert to geographic point"
    end
  end
end

class DeliverPackage < CMDx::Task
  register :coercion, :geo_point, GeoCoercion

  required :origin, type: :geo_point
  required :destination, type: :geo_point

  def work
    origin      # => Geo::Point instance
    destination # => Geo::Point instance
  end
end
```

Same pattern for validators:

```ruby
class UUIDValidator
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def self.call(value, options = {})
    return if value.nil? && options[:allow_nil]
    raise CMDx::ValidationError, "is not a valid UUID" unless value.to_s.match?(UUID_PATTERN)
  end
end

class ProcessEntity < CMDx::Task
  register :validator, :uuid, UUIDValidator

  required :entity_id, uuid: true

  def work
    entity_id # Guaranteed to be a valid UUID format
  end
end
```

## Putting It All Together

Here's a real-world example combining everything—a task that processes subscription upgrades:

```ruby
class UpgradeSubscription < CMDx::Task
  # Core identifiers
  required :user_id, uuid: true
  required :subscription_id, uuid: true

  # Plan details with validation
  required :new_plan,
    type: :symbol,
    inclusion: { in: [:starter, :professional, :enterprise] }

  # Payment info (conditionally required)
  required :payment_method_id, uuid: true, unless: :enterprise_invoicing?

  optional :billing do
    required :address_line1, presence: true
    optional :address_line2
    required :city, presence: true
    required :postal_code, format: /\A\d{5}(-\d{4})?\z/
    required :country, inclusion: { in: ISO3166::Country.codes }
  end

  # Proration settings
  optional :prorate, default: true, type: :boolean
  optional :proration_date,
    type: :datetime,
    default: -> { Time.current }

  # Contact preferences
  optional :notification_email,
    transform: ->(v) { v.to_s.downcase.strip },
    format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    subscription = Subscription.find(subscription_id)

    subscription.upgrade!(
      plan: new_plan,
      payment_method_id: payment_method_id,
      prorate: prorate,
      proration_date: proration_date,
      billing_address: billing
    )

    if notification_email
      SubscriptionMailer.upgrade_confirmation(notification_email, subscription).deliver_later
    end

    context.subscription = subscription
  end

  private

  def enterprise_invoicing?
    context.new_plan == :enterprise
  end
end
```

Every attribute has a clear purpose. Types are explicit. Validations are declarative. The task's interface is self-documenting.

## The Payoff

Well-designed attributes give you:

1. **Self-documenting interfaces** — One glance tells you what data the task needs
2. **Fail-fast behavior** — Invalid data never reaches your business logic
3. **Consistent error handling** — Structured errors, every time
4. **Less defensive coding** — Trust your attributes, focus on business logic

The time you invest in thoughtful attribute design pays dividends in debugging time saved and confidence gained. Your future self (and your teammates) will thank you.

Next time you're building a task, start with the attributes. Ask yourself: What data do I need? What shape should it be in? What makes it valid? Answer those questions with attributes, and the rest follows naturally.
