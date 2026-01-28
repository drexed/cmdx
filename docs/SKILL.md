---
name: cmdx-ruby
description: Builds business logic with CMDx, a Ruby framework for composable command/service objects. Use when creating service objects, interactors, business workflows, command patterns, or orchestrating multi-step operations in Ruby/Rails applications.
---

# CMDx - Ruby Business Logic Framework

CMDx structures business logic through Tasks (single operations) and Workflows (task pipelines) using the CERO pattern: Compose, Execute, React, Observe.

## Quick Start

```ruby
class ProcessPayment < CMDx::Task
  required :amount, type: :big_decimal, numeric: { min: 0.01 }
  required :user_id, type: :integer
  optional :currency, default: "USD"

  on_success :send_receipt!

  def work
    return fail!("User not found", code: 404) if user.nil?
    return skip!("Already processed") if already_processed?

    context.transaction = Gateway.charge(amount:, currency:)
    context.processed_at = Time.current
  end

  private

  def user = @user ||= User.find_by(id: user_id)
  def already_processed? = context.transaction.present?
  def send_receipt! = PaymentMailer.receipt(user).deliver_later
end

# Execute and react
result = ProcessPayment.execute(amount: 99.99, user_id: 123)
result.success? && result.context.transaction
```

## Attributes

### Declarations

```ruby
class CreateUser < CMDx::Task
  required :email, type: :string, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :age, type: :integer, numeric: { min: 18, max: 120 }
  optional :role, default: "user", inclusion: { in: %w[user admin] }
  optional :notes, transform: :strip  # Transform before validation

  # Nested attributes
  required :address do
    required :street, :city, type: :string
    optional :zip, type: :string, length: { is: 5 }
  end

  # Source from other objects
  attribute :tenant_id, source: -> { Current.tenant&.id }

  def work
    # Access via method: email, age, role, address[:street]
    # Or via context: context.email, context.fetch!(:role, "guest")
  end
end
```

### Built-in Types

| Type | Coerces from | Options |
|------|-------------|---------|
| `:string` | Any via `to_s` | |
| `:integer` | String, Float | Hex/octal support |
| `:float` | String, Integer | |
| `:big_decimal` | String, Numeric | `:precision` |
| `:boolean` | "true"/"false", "yes"/"no", 0/1 | |
| `:date` | String | `:strptime` |
| `:time` | String | `:strptime` |
| `:datetime` | String | `:strptime` |
| `:array` | String (JSON) | |
| `:hash` | String (JSON) | |
| `:symbol` | String | |
| `:rational` | String ("1/2") | |
| `:complex` | String ("1+2i") | |

### Validations

```ruby
required :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+\.[a-z]+\z/i }
required :age, numeric: { min: 18, max: 120 }
required :status, inclusion: { in: %w[active pending] }
required :name, length: { min: 2, max: 100 }
required :banned, absence: true   # Must be nil/blank
required :terms, presence: true   # Must be present
optional :code, exclusion: { in: %w[admin root] }

# Conditional validation
required :manager_id, if: :requires_approval?
```

## Context & Data Flow

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Read from context
    weight = context.weight
    destination = context[:destination]
    rush = context.fetch!(:rush, false)

    # Write to context
    context.shipping_cost = calculate_cost
    context.merge!(carrier: "FedEx", estimated_days: 3)

    # Pass to subtasks (context is shared)
    ValidateAddress.execute(context)
  end
end
```

## Control Flow

| Method | When to use | Result |
|--------|-------------|--------|
| `fail!(reason, **meta)` | Business rule violated | `failed?` = true |
| `skip!(reason, **meta)` | Nothing to do | `skipped?` = true |
| `throw!(result, **meta)` | Propagate subtask failure | Preserves chain |

```ruby
def work
  # Propagate failures from subtasks
  validation = ValidateData.execute(context)
  throw!(validation) if validation.failed?

  # Continue processing...
end
```

## Results & Handlers

```ruby
result = ProcessPayment.execute(amount: 99.99, user_id: 123)

# Status checks
result.success?   # Completed successfully
result.failed?    # Business failure
result.skipped?   # Intentionally skipped
result.good?      # success OR skipped
result.bad?       # failed OR skipped

# Access data
result.context.transaction   # Output data
result.reason                # Why it failed/skipped
result.metadata[:code]       # Custom metadata
result.retries               # Number of retry attempts
result.rolled_back?          # Was rollback called?

# Fluent handlers
result
  .on(:success) { |r| notify_user(r.context) }
  .on(:failed) { |r| alert_admin(r.reason) }
  .on(:skipped) { |r| log_skip(r.reason) }

# Pattern matching (Ruby 3.0+)
case result
in { status: "success" }
  redirect_to success_path
in { status: "failed", metadata: { retryable: true } }
  schedule_retry
end
```

## Bang Execution

```ruby
begin
  result = ProcessPayment.execute!(amount: 99.99, user_id: 123)
rescue CMDx::FailFault => e
  e.result.reason        # Error message
  e.context.user_id      # Input data
  e.chain.id             # Execution chain ID
rescue CMDx::SkipFault => e
  # Handle skip condition
end
```

## Workflows

```ruby
class CheckoutWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ProcessPayment, if: :payment_required?
  task CreateOrder
  task SendConfirmation, unless: :guest_checkout?

  # Grouped tasks with shared config
  tasks NotifyWarehouse, UpdateInventory, breakpoints: []

  # Parallel execution (requires 'parallel' gem)
  tasks SendEmail, SendSMS, SendPush, strategy: :parallel

  private

  def payment_required? = context.total.positive?
  def guest_checkout? = context.user.guest?
end
```

## Callbacks

```ruby
class Task < CMDx::Task
  before_validation :normalize_inputs
  before_execution :setup
  after_execution :cleanup

  on_complete :always_run        # After work, any outcome
  on_success :notify_user
  on_failure :alert_admin
  on_skipped :log_skip

  # Conditional callbacks
  on_success :send_email, if: :email_enabled?
end
```

## Middleware

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { Current.request_id }
  register :middleware, CMDx::Middlewares::Timeout, seconds: 30
  register :middleware, CMDx::Middlewares::Runtime  # Adds metadata[:runtime]
end

# Custom middleware
class AuditMiddleware
  def call(task, options)
    result = yield
    AuditLog.record(task.class.name, result.status)
    result
  end
end
```

## Retries

```ruby
class FetchExternalData < CMDx::Task
  settings retries: 3, retry_on: [Net::ReadTimeout, Faraday::TimeoutError]
  settings retry_jitter: 2  # Linear delay: jitter * retry_count

  # Exponential backoff
  settings retry_jitter: ->(n) { 2 ** n }  # 2s, 4s, 8s...

  def work
    context.data = ExternalAPI.fetch(context.id)
  end
end
```

## Rollback

```ruby
class ChargeCard < CMDx::Task
  def work
    context.charge = StripeApi.charge(context.amount)
  end

  def rollback
    StripeApi.refund(context.charge.id) if context.charge
  end
end

# Configure when rollback runs
CMDx.configure { |c| c.rollback_on = ["failed"] }
```

## Configuration

```ruby
CMDx.configure do |config|
  config.task_breakpoints = ["failed"]      # When execute! raises
  config.workflow_breakpoints = ["failed"]  # When workflow halts
  config.rollback_on = ["failed"]
  config.logger = Rails.logger

  # Global middleware/callbacks
  config.middlewares.register CMDx::Middlewares::Runtime
  config.callbacks.register :on_failure, ErrorTracker
end
```

## Task Settings

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    breakpoints: ["failed"],
    log_level: :info,
    tags: ["billing"],
    retries: 3,
    deprecated: :warn  # :log, :warn, :raise
  )
end
```

## Naming Conventions

- **Tasks**: Verb + noun → `ProcessPayment`, `ValidateOrder`
- **Workflows**: Verb + plural → `SendNotifications`, `ProcessOrders`
- **Namespaces**: Domain → `Billing::GenerateInvoice`, `Shipping::CreateLabel`

## Best Practices

1. **Single responsibility**: One task = one operation
2. **Use context for data sharing**: `context.result = value`
3. **Control flow via fail!/skip!**: Not exceptions
4. **Memoize lookups**: `def user = @user ||= User.find(id)`
5. **Validate at boundaries**: Use typed attributes
6. **Define rollback**: For reversible operations

## Rails Generators

```bash
rails generate cmdx:install          # Config file
rails generate cmdx:task ProcessPayment
rails generate cmdx:workflow CheckoutWorkflow
```

## References

- [Full Documentation](https://drexed.github.io/cmdx)
- [Attributes Guide](https://drexed.github.io/cmdx/attributes/definitions)
- [Workflows Guide](https://drexed.github.io/cmdx/workflows)
- [GitHub](https://github.com/drexed/cmdx)
