---
name: cmdx-ruby
description: Build business logic with CMDx, a Ruby framework for composable command objects. Use when creating service objects, business workflows, or command patterns in Ruby/Rails applications.
---

# CMDx - Ruby Business Logic Framework

CMDx structures business logic through Tasks (single operations) and Workflows (task pipelines).

## Core Concepts

### Task Structure

```ruby
class ProcessPayment < CMDx::Task
  # Attributes (validated inputs)
  required :amount, type: :big_decimal, numeric: { min: 0.01 }
  required :user_id, type: :integer
  optional :currency, default: "USD"

  # Callbacks
  on_success :send_receipt!

  def work
    # Use fail!/skip! for control flow, NOT exceptions
    return fail!("User not found", code: 404) if user.nil?
    return skip!("Already processed") if already_processed?

    # Store results in context
    context.transaction = Gateway.charge(amount:, currency:)
    context.processed_at = Time.current
  end

  private

  def user = @user ||= User.find_by(id: user_id)
  def already_processed? = context.transaction.present?
  def send_receipt! = PaymentMailer.receipt(user).deliver_later
end
```

### Workflow Structure

```ruby
class CheckoutWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ProcessPayment
  task CreateOrder
  task SendConfirmation, if: :notifications_enabled?

  private

  def notifications_enabled? = context.user.notifications_enabled?
end
```

## Execution & Results

```ruby
# Execute
result = ProcessPayment.execute(amount: 99.99, user_id: 123)

# React to outcome
case
when result.success?
  result.context.transaction  # Access stored data
when result.skipped?
  result.reason               # Why it was skipped
when result.failed?
  result.reason               # Error message
  result.metadata[:code]      # Custom metadata
end
```

## Attribute Types

Built-in types with automatic coercion:

| Type | Coerces from |
|------|-------------|
| `:string` | Any via `to_s` |
| `:integer` | String, Float |
| `:float` | String, Integer |
| `:big_decimal` | String, Numeric |
| `:boolean` | "true"/"false", 0/1 |
| `:date` | String (ISO 8601) |
| `:time` | String (ISO 8601) |
| `:array` | String (JSON) |
| `:hash` | String (JSON) |
| `:symbol` | String |

## Validations

```ruby
required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
required :age, numeric: { min: 18, max: 120 }
required :status, inclusion: { in: %w[active pending] }
required :name, length: { min: 2, max: 100 }
required :banned, absence: true  # Must be nil/blank
required :terms, presence: true  # Must be present
```

## Control Flow

| Method | When to use |
|--------|-------------|
| `fail!(reason, **metadata)` | Validation failed, business rule violated |
| `skip!(reason, **metadata)` | Precondition not met, nothing to do |
| `halt!(reason, **metadata)` | Stop workflow, mark success |

## Callbacks

```ruby
class Task < CMDx::Task
  before_execution :setup
  after_execution :cleanup
  on_success :notify
  on_failure :alert
  on_skipped :log_skip
end
```

## Middleware

```ruby
class Task < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { Current.request_id }
  register :middleware, CMDx::Middlewares::Timeout, seconds: 30
  register :middleware, CMDx::Middlewares::Runtime
end
```

## Configuration

```ruby
CMDx.configure do |config|
  config.log_level = :info              # :debug, :info, :warn, :error
  config.log_formatter = :json          # :json, :key_value, :line, :logstash, :raw
  config.task_breakpoints = ["failed"]  # Halt on these statuses
  config.workflow_breakpoints = ["failed"]
end
```

## Naming Conventions

- **Tasks**: Present tense verb + noun → `ProcessPayment`, `ValidateOrder`
- **Workflows**: Verb + plural noun → `SendNotifications`, `ProcessOrders`
- **Namespaces**: Domain boundaries → `Billing::GenerateInvoice`, `Shipping::CreateLabel`

## Best Practices

1. **Single responsibility**: One task = one operation
2. **Use context for data sharing**: `context.result = value`
3. **Control flow via fail!/skip!**: Not exceptions
4. **Memoize expensive lookups**: `def user = @user ||= User.find(id)`
5. **Validate at boundaries**: Use typed attributes
6. **Rollback for reversible operations**: Define `rollback` method

## Rails Generator

```bash
rails generate cmdx:task ProcessPayment
rails generate cmdx:workflow CheckoutWorkflow
```

## Documentation

- [Full Documentation](https://drexed.github.io/cmdx)
- [Getting Started](https://drexed.github.io/cmdx/getting_started)
- [GitHub](https://github.com/drexed/cmdx)
