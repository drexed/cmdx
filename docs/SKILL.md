---
name: cmdx-ruby
description: Builds business logic with CMDx, a Ruby framework for composable command/service objects. Use when creating service objects, interactors, business workflows, command patterns, or orchestrating multi-step operations in Ruby/Rails applications.
---

# CMDx - Ruby Business Logic Framework

CMDx structures business logic through Tasks (single operations) and Workflows (task pipelines) using the CERO pattern.

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

result = ProcessPayment.execute(amount: 99.99, user_id: 123)
result.success? && result.context.transaction
```

## CERO Pattern

CMDx tasks follow the **CERO** lifecycle — Compose, Execute, React, Observe:

1. **Compose** — Declare and validate inputs via typed attributes with coercion, defaults, and validators.
2. **Execute** — Run business logic in the `work` method, using `fail!`/`skip!`/`throw!` for control flow.
3. **React** — Respond to outcomes via callbacks (`on_success`, `on_failed`, etc.) and fluent `on` handlers.
4. **Observe** — Inspect results through the `Result` object, chain tracking, logging, and pattern matching.

## The `work` Method

Every task **must** override `work`. It is the only required method. Failing to define it raises `CMDx::UndefinedMethodError`.

```ruby
class MyTask < CMDx::Task
  def work
    # Business logic here
    # Use fail!, skip!, throw! for control flow
    # Write outputs to context
  end
end
```

Workflows define `work` automatically — you **cannot** redefine it in a workflow class.

## Attributes

### Declarations

```ruby
class CreateUser < CMDx::Task
  required :email, type: :string, format: { with: URI::MailTo::EMAIL_REGEXP }
  required :age, type: :integer, numeric: { min: 18, max: 120 }
  optional :role, default: "user", inclusion: { in: %w[user admin] }
  optional :notes, transform: :strip

  # Multiple types (union)
  required :external_id, types: [:string, :integer]

  # Nested attributes
  required :address do
    required :street, :city, type: :string
    optional :zip, type: :string, length: { is: 5 }
  end

  # Source from other objects
  attribute :tenant_id, source: -> { Current.tenant&.id }

  # Conditional requirement
  required :manager_id, if: :requires_approval?

  def work
    # Access via method: email, age, role, address[:street]
    # Or via context: context.email, context.fetch(:role, "guest")
  end
end
```

The `required`, `optional`, and `attribute` (alias `attributes`) class methods declare inputs:

- `required` — Must be present (sets `required: true`)
- `optional` — May be absent (sets `required: false`)
- `attribute` / `attributes` — Generic declaration (defaults to `required: false`)

Multiple attribute names can share the same options: `required :first_name, :last_name, type: :string`

### Attribute Options Reference

| Option | Type | Description |
|--------|------|-------------|
| `type:` | Symbol | Single expected type (see Built-in Types) |
| `types:` | Array | Multiple accepted types (union) |
| `default:` | Object / Symbol / Proc | Default value when absent |
| `transform:` | Symbol / Proc | Transform value before validation |
| `source:` | Symbol / String / Proc / Callable | Where to read the value (default: `:context`) |
| `as:` | Symbol / String | Override the accessor method name |
| `prefix:` | Symbol / String / `true` | Prefix the method name (`true` → `"#{source}_"`) |
| `suffix:` | Symbol / String / `true` | Suffix the method name (`true` → `"_#{source}"`) |
| `description:` | String | Human-readable description (alias: `desc:`) |
| `if:` | Symbol / Proc / Callable | Conditional — only validate/require when truthy |
| `unless:` | Symbol / Proc / Callable | Conditional — skip validation/requirement when truthy |
| `required:` | Boolean | Explicitly set requirement (used internally) |

### Built-in Types

| Type | Coerces from | Options |
|------|-------------|---------|
| `:string` | Any via `to_s` | |
| `:integer` | String, Float | Hex/octal support |
| `:float` | String, Integer | |
| `:big_decimal` | String, Numeric | `:precision` |
| `:boolean` | "true"/"false", "yes"/"no", 0/1 (case-insensitive) | |
| `:date` | String | `:strptime` |
| `:time` | String | `:strptime` |
| `:datetime` | String | `:strptime` |
| `:array` | String (JSON) | |
| `:hash` | String (JSON) | |
| `:symbol` | String | |
| `:rational` | String ("1/2") | |
| `:complex` | String ("1+2i") | |

Custom coercions can be registered — see the [Coercions Guide](https://drexed.github.io/cmdx/attributes/coercions).

### Validations

```ruby
required :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+\.[a-z]+\z/i }
required :age, numeric: { min: 18, max: 120 }
required :status, inclusion: { in: %w[active pending] }
required :name, length: { min: 2, max: 100 }
required :banned, absence: true    # Must be nil/blank
required :terms, presence: true    # Must be present
optional :code, exclusion: { in: %w[admin root] }
```

Built-in validators: `absence`, `presence`, `format`, `inclusion`, `exclusion`, `length`, `numeric`. Custom validators can be registered — see the [Validators Guide](https://drexed.github.io/cmdx/attributes/validators).

### Introspection & Removal

```ruby
# Inspect the attribute schema
CreateUser.attributes_schema
# => { email: { name: :email, method_name: :email, required: true, types: [:string], ... }, ... }

# Remove inherited attributes in subclasses
class AdminUser < CreateUser
  remove_attributes :role, :manager_id
end
```

## Context

Context is a shared, hash-like object that flows through tasks and workflows. Keys are automatically symbolized.

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Read
    weight = context.weight          # method_missing accessor
    destination = context[:destination]  # bracket access
    rush = context.fetch(:rush, false)   # fetch with default
    zip = context.dig(:address, :zip)    # nested dig

    # Atomic get-or-set
    context.fetch_or_store(:cache_key) { compute_expensive_key }

    # Write
    context.shipping_cost = calculate_cost
    context.merge!(carrier: "FedEx", estimated_days: 3)
    context.store(:tracking_id, generate_id)

    # Delete / Clear
    context.delete(:temp_data)
    # context.clear!  # removes all keys

    # Check existence
    context.key?(:weight)  # => true

    # Iteration
    context.each { |k, v| log(k, v) }
    context.to_h  # => { weight: 10, ... }

    # Pass to subtasks (context is shared)
    ValidateAddress.execute(context)
  end
end
```

**Aliases:** `merge` = `merge!`, `delete` = `delete!`, `clear` = `clear!`

## Control Flow

| Method | When to use | Result |
|--------|-------------|--------|
| `fail!(reason, **meta)` | Business rule violated | `failed?` = true |
| `skip!(reason, **meta)` | Nothing to do | `skipped?` = true |
| `throw!(result, **meta)` | Propagate subtask failure | Preserves state/status/reason |

`fail!` and `skip!` accept: `reason` (String, optional), `halt:` (Boolean, default: `true`), `cause:` (Exception, optional), `**metadata`. `throw!` accepts: `result` (Result), `halt:`, `cause:`, `**metadata` — it copies state/status/reason from the given result.

```ruby
def work
  # Direct failure
  return fail!("Insufficient funds", code: 402) if insufficient_funds?

  # Propagate failures from subtasks
  validation = ValidateData.execute(context)
  throw!(validation) if validation.failed?

  # Skip with metadata
  return skip!("Already processed", skipped_at: Time.current) if processed?

  # Non-halting failure (continues execution, sets status but doesn't raise)
  fail!("Partial failure", halt: false) if partial_issue?
end
```

## Results

### Status & State Predicates

```ruby
result = ProcessPayment.execute(amount: 99.99, user_id: 123)

# States (lifecycle)
result.initialized?  # Before execution
result.executing?    # During work
result.complete?     # Finished successfully
result.interrupted?  # Halted (failed or skipped)
result.executed?     # complete? || interrupted?

# Statuses (outcome)
result.success?      # Completed successfully
result.failed?       # Business failure
result.skipped?      # Intentionally skipped

# Compound predicates
result.good?         # !failed? (success OR skipped)
result.ok?           # Alias for good?
result.bad?          # !success? (failed OR skipped)

# Retry / rollback predicates
result.retried?      # retries > 0
result.rolled_back?  # Was rollback called?

# Data access
result.context       # Shared context (alias: ctx)
result.reason        # Why it failed/skipped (String or nil)
result.cause         # Exception that caused interruption (or nil)
result.metadata      # Custom metadata hash (Symbol keys)
result.retries       # Number of retry attempts (Integer)
result.outcome       # "success"/"failed"/"skipped" or state for thrown failures
result.index         # Position in the execution chain
result.chain         # The execution chain
result.errors        # Errors collection (delegated from task)
result.dry_run?      # Whether running in dry-run mode
```

### Fluent Handlers

The `on` method accepts any predicate name (states, statuses, or compound). Returns `self` for chaining.

```ruby
result
  .on(:success) { |r| notify_user(r.context) }
  .on(:failed) { |r| alert_admin(r.reason) }
  .on(:skipped) { |r| log_skip(r.reason) }
  .on(:good) { |r| track_completion(r) }
  .on(:bad) { |r| track_issue(r) }
  .on(:interrupted) { |r| cleanup(r) }
  .on(:retried) { |r| log_retries(r.retries) }

# Multiple predicates (yields if ANY match)
result.on(:success, :skipped) { |r| consider_done(r) }
```

### Pattern Matching

```ruby
# Array deconstruction
state, status, reason, cause, metadata = result.deconstruct

# Hash deconstruction (Ruby 3.0+)
case result
in { status: "success", good: true }
  redirect_to success_path
in { status: "failed", metadata: { retryable: true } }
  schedule_retry
in { bad: true }
  handle_issue(result.reason)
end

# Available keys: state, status, reason, cause, metadata, outcome, executed, good, bad
```

### Failure Analysis

When tasks are chained (e.g., in workflows), results track failure provenance:

```ruby
result.caused_failure    # => Result that originally caused the failure (or nil)
result.caused_failure?   # => true if THIS result caused the failure
result.threw_failure     # => Result that threw/propagated the failure (or nil)
result.threw_failure?    # => true if THIS result threw the failure
result.thrown_failure?   # => true if this is a propagated (not originated) failure
```

### Errors

Validation errors are collected in an `Errors` object, accessible from both the task and result:

```ruby
result.errors.empty?            # => true/false
result.errors.for?(:email)      # => true if email has errors
result.errors.to_h              # => { email: ["is invalid"], age: ["must be >= 18"] }
result.errors.full_messages     # => { email: ["email is invalid"], age: ["age must be >= 18"] }
result.errors.to_hash(true)     # => full_messages format
result.errors.to_s              # => "email is invalid. age must be >= 18"
```

## Bang Execution & Faults

```ruby
begin
  result = ProcessPayment.execute!(amount: 99.99, user_id: 123)
rescue CMDx::FailFault => e
  e.result.reason        # Error message
  e.context.user_id      # Input data
  e.chain.id             # Execution chain ID
rescue CMDx::SkipFault => e
  e.result.reason        # Skip reason
end
```

`execute!` raises faults when the result status matches the configured `breakpoints` (default: `["failed"]`).

### Fault Matching

Use `for?` and `matches?` to create targeted rescue clauses:

```ruby
begin
  result = ProcessCheckouts.execute!(items:, user:)
rescue CMDx::FailFault.for?(ProcessPayment, ChargeCard) => e
  # Only catches failures from ProcessPayment or ChargeCard tasks
  handle_payment_failure(e)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:retryable] } => e
  # Only catches failures where metadata[:retryable] is truthy
  schedule_retry(e)
rescue CMDx::FailFault => e
  # Catches all other failures
  handle_generic_failure(e)
end
```

### Block Yielding

Both `execute` and `execute!` accept blocks:

```ruby
ProcessPayment.execute(amount: 99.99) do |result|
  result.on(:success) { |r| redirect_to(r.ctx.receipt_url) }
  result.on(:failed) { |r| render_error(r.reason) }
end
```

## Callbacks

All 10 callback types, with execution order:

| Phase | Callback | Fires when |
|-------|----------|------------|
| Pre | `before_validation` | Before attribute validation |
| Pre | `before_execution` | Before `work` runs |
| Post | `on_complete` | State = complete |
| Post | `on_interrupted` | State = interrupted |
| Post | `on_executed` | State = complete OR interrupted |
| Post | `on_success` | Status = success |
| Post | `on_skipped` | Status = skipped |
| Post | `on_failed` | Status = failed |
| Post | `on_good` | good? = true (success or skipped) |
| Post | `on_bad` | bad? = true (failed or skipped) |

```ruby
class ProcessOrder < CMDx::Task
  before_validation :normalize_inputs
  before_execution :setup

  on_complete :always_run
  on_success :notify_user
  on_failed :alert_admin
  on_skipped :log_skip
  on_good :track_completion
  on_bad :track_issue

  # Conditional callbacks
  on_success :send_email, if: :email_enabled?
  on_failed :page_oncall, unless: :business_hours?

  # Block callbacks
  on_success { logger.info("Order processed") }

  # Callable objects
  on_failed AuditLogger
end
```

Callables: **Symbol** (method name), **Proc** (instance_exec'd), or any object responding to `call(task)`.

## Workflows

Workflows orchestrate multiple tasks through a shared context:

```ruby
class ProcessOrders < CMDx::Task
  include CMDx::Workflow

  task ValidateCart
  task ProcessPayment, if: :payment_required?
  task CreateOrder
  task SendConfirmation, unless: :guest_checkout?

  # Grouped tasks with shared config
  tasks NotifyWarehouse, UpdateInventory, breakpoints: []

  # Parallel execution (requires 'parallel' gem)
  tasks SendEmail, SendSMS, SendPush, strategy: :parallel
  tasks HeavyTask1, HeavyTask2, strategy: :parallel, in_threads: 4

  private

  def payment_required? = context.total.positive?
  def guest_checkout? = context.user.guest?
end
```

**Workflow options:**

| Option | Type | Description |
|--------|------|-------------|
| `if:` | Symbol / Proc / Callable | Execute group only when truthy |
| `unless:` | Symbol / Proc / Callable | Skip group when truthy |
| `breakpoints:` | Array | Statuses that halt the workflow (default: `["failed"]`) |
| `strategy:` | Symbol / String | `:sequential` (default) or `:parallel` |
| `in_threads:` | Integer | Thread count for parallel strategy |
| `in_processes:` | Integer | Process count for parallel strategy |

Access the pipeline definition: `ProcessOrders.pipeline` → `Array<ExecutionGroup>`

## Middleware

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { Current.request_id }
  register :middleware, CMDx::Middlewares::Timeout, seconds: 30
  register :middleware, CMDx::Middlewares::Runtime
end
```

### Built-in Middlewares

| Middleware | Effect | Key options |
|-----------|--------|-------------|
| `Correlate` | Thread-safe correlation ID tracking | `id:` (Symbol/Proc/String), `if:`, `unless:` |
| `Timeout` | Enforces time limit (raises `CMDx::TimeoutError`) | `seconds:` (Numeric/Symbol/Proc, default: 3), `if:`, `unless:` |
| `Runtime` | Measures execution time in ms | `if:`, `unless:` |

Access correlation ID: `CMDx::Middlewares::Correlate.id`
Runtime stored in: `result.metadata[:runtime]`

### Custom Middleware

```ruby
module AuditMiddleware
  extend self

  def call(task, **options)
    result = yield
    AuditLog.record(task.class.name, result.status) unless task.dry_run?
    result
  end
end

register :middleware, AuditMiddleware
```

## Retries

```ruby
class FetchExternalData < CMDx::Task
  settings(
    retries: 3,
    retry_on: [Net::ReadTimeout, Faraday::TimeoutError],
    retry_jitter: 2  # Linear delay: jitter * retry_count (seconds)
  )

  # Exponential backoff via proc
  # settings retry_jitter: ->(n) { 2 ** n }  # 2s, 4s, 8s...

  # Backoff via method name
  # settings retry_jitter: :compute_delay

  def work
    context.data = ExternalAPI.fetch(context.id)
  end

  # private
  # def compute_delay(retry_count) = 2 ** retry_count
end
```

**Retry settings:**

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `retries:` | Integer | `0` | Maximum retry attempts |
| `retry_on:` | Array\<Class\> | `[StandardError]` | Exception classes to retry on |
| `retry_jitter:` | Numeric / Symbol / Proc / Callable | `nil` | Delay between retries |

**Jitter evaluation:** Numeric → `jitter * retry_count`, Symbol → `task.send(sym, count)`, Proc → `instance_exec(count)`, Callable → `.call(task, count)`.

After retries, `result.retries` reflects the count and `result.retried?` returns `true`.

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
```

Rollback runs automatically after execution when `result.status` matches `rollback_on` (default: `["failed"]`). After rollback, `result.rolled_back?` returns `true`. Implement a `rollback` instance method to opt in.

## Dry Run

Pass `dry_run: true` in the context to signal dry-run mode. The flag is inherited by all nested/subtask executions in the chain.

```ruby
result = ProcessPayment.execute(amount: 99.99, user_id: 123, dry_run: true)
result.dry_run?  # => true

# Inside work:
def work
  return skip!("Dry run") if dry_run?
  # ... real logic
end
```

`dry_run?` is available on the task, result, and chain objects.

## Deprecation

Mark tasks as deprecated to warn or prevent usage:

```ruby
class LegacyTask < CMDx::Task
  settings deprecate: "warn"  # Outputs to stderr via Kernel#warn
end

# Other deprecation modes:
# settings deprecate: "log"    # Logs warning via task logger
# settings deprecate: "raise"  # Raises CMDx::DeprecationError
# settings deprecate: true     # Same as "raise"
# settings deprecate: false    # No deprecation (default)
# settings deprecate: :check_deprecation  # Calls method, evaluates return value
# settings deprecate: -> { Date.today > Date.new(2026, 6, 1) ? "raise" : "warn" }
```

## Logging

### Log Formatters

Set via configuration or task settings:

```ruby
CMDx.configure do |config|
  config.logger = Logger.new($stdout, progname: "cmdx")
  config.logger.formatter = CMDx::LogFormatters::JSON.new
end
```

| Formatter | Output |
|-----------|--------|
| `LogFormatters::Line` | Human-readable single line (default) |
| `LogFormatters::JSON` | Structured JSON with severity, timestamp, pid |
| `LogFormatters::KeyValue` | `key=value` pairs |
| `LogFormatters::Logstash` | Logstash-compatible JSON |
| `LogFormatters::Raw` | Unformatted message |

### Backtrace Logging

```ruby
class ApplicationTask < CMDx::Task
  settings(
    backtrace: true,  # Log exception backtraces on failure
    backtrace_cleaner: ->(bt) { bt.reject { |l| l.include?("/gems/") }.first(10) }
  )
end
```

### Exception Handler

```ruby
class ApplicationTask < CMDx::Task
  settings exception_handler: ->(task, error) { Sentry.capture_exception(error) }
end
```

Called when a `StandardError` (non-fault) is rescued during execution.

## Configuration

```ruby
CMDx.configure do |config|
  # Breakpoints — statuses that trigger execute! to raise
  config.task_breakpoints = ["failed"]          # Default
  config.workflow_breakpoints = ["failed"]      # Default

  # Rollback — statuses that trigger rollback
  config.rollback_on = ["failed"]               # Default

  # Logging
  config.logger = Rails.logger
  config.backtrace = false                      # Default
  config.backtrace_cleaner = nil                # Default (Proc or nil)
  config.exception_handler = nil                # Default (Proc or nil)

  # Global middleware
  config.middlewares.register CMDx::Middlewares::Runtime

  # Global callbacks
  config.callbacks.register :on_failed, ErrorTracker
end
```

Reset to defaults: `CMDx.reset_configuration!`

### I18n Support

CMDx ships with 80+ locale files for validation and fault messages. In Rails, the railtie auto-loads them. Custom locale files can be generated:

```bash
rails generate cmdx:locale
```

## Task Settings

Per-task settings override global configuration and inherit from parent classes:

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    # Breakpoints
    breakpoints: ["failed"],            # Task-level breakpoints (overrides task_breakpoints)

    # Retries
    retries: 3,
    retry_on: [StandardError],
    retry_jitter: 2,

    # Rollback
    rollback_on: ["failed"],

    # Logging
    log_level: :info,
    backtrace: true,
    backtrace_cleaner: nil,
    exception_handler: nil,

    # Tags
    tags: ["billing"],

    # Deprecation
    deprecate: false
  )
end
```

**Inheritance:** All settings inherit from the parent class, except `backtrace_cleaner`, `exception_handler`, `logger`, and `deprecate` which fall back to global configuration.

### Register / Deregister

```ruby
class MyTask < CMDx::Task
  # Register custom components
  register :middleware, CustomMiddleware
  register :callback, :on_success, :notify
  register :validator, :custom, CustomValidator
  register :coercion, :money, MoneyCoercion

  # Remove inherited components
  deregister :middleware, CustomMiddleware
  deregister :callback, :on_success, :notify
end
```

## Naming Conventions

- **Tasks**: Verb + noun → `ProcessPayment`, `ValidateOrder`, `CreateUser`
- **Workflows**: Verb + noun (plural) → `SendNotifications`, `ProcessOrders`, `SyncAccounts`
- **Namespaces**: Domain → `Billing::GenerateInvoice`, `Shipping::CreateLabel`

## Best Practices

1. **Single responsibility**: One task = one operation
2. **Use context for data sharing**: `context.output = value`
3. **Control flow via fail!/skip!**: Not exceptions
4. **Memoize lookups**: `def user = @user ||= User.find(id)`
5. **Validate at boundaries**: Use typed attributes with validators
6. **Define rollback**: For any reversible side effects
7. **Use dry_run**: For safe previewing of destructive operations
8. **Inherit from ApplicationTask**: Set shared middleware, logging, and settings once

## Rails Generators

```bash
rails generate cmdx:install                # Config initializer
rails generate cmdx:task ProcessPayment    # Task file
rails generate cmdx:workflow SyncAccounts  # Workflow file
rails generate cmdx:locale                 # I18n locale files
```

## Exceptions Reference

| Class | Parent | Raised when |
|-------|--------|-------------|
| `CMDx::Error` | `StandardError` | Base exception (alias: `CMDx::Exception`) |
| `CMDx::Fault` | `Error` | Base fault (has `.result`, `.task`, `.context`, `.chain`) |
| `CMDx::FailFault` | `Fault` | Task failed and halt triggered |
| `CMDx::SkipFault` | `Fault` | Task skipped and halt triggered |
| `CMDx::CoercionError` | `Error` | Attribute type coercion failed |
| `CMDx::ValidationError` | `Error` | Attribute validation failed |
| `CMDx::DeprecationError` | `Error` | Deprecated task used with `deprecate: true/"raise"` |
| `CMDx::UndefinedMethodError` | `Error` | `work` method not implemented |
| `CMDx::TimeoutError` | `Interrupt` | Timeout middleware limit exceeded |

## References

- [Full Documentation](https://drexed.github.io/cmdx)
- [Attributes Guide](https://drexed.github.io/cmdx/attributes/definitions)
- [Workflows Guide](https://drexed.github.io/cmdx/workflows)
- [GitHub](https://github.com/drexed/cmdx)
