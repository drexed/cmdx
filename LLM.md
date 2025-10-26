# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. It brings structure, consistency, and powerful developer tools to your business processes.

**Common challenges it solves:**

- Inconsistent service object patterns across your codebase
- Limited logging makes debugging a nightmare
- Fragile error handling erodes confidence

**What you get:**

- Consistent, standardized architecture
- Built-in flow control and error handling
- Composable, reusable workflows
- Comprehensive logging for observability
- Attribute validation with type coercions
- Sensible defaults and developer-friendly APIs

## The CERO Pattern

CMDx embraces the Compose, Execute, React, Observe (CERO) pattern—a simple yet powerful approach to building reliable business logic.

🧩 **Compose** — Define small, focused tasks with typed attributes and validations

⚡ **Execute** — Run tasks with clear outcomes and pluggable behaviors

🔄 **React** — Adapt to outcomes by chaining follow-up tasks or handling faults

🔍 **Observe** — Capture structured logs and execution chains for debugging

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

This creates `config/initializers/cmdx.rb` file.

## Configuration Hierarchy

CMDx uses a straightforward two-tier configuration system:

1. **Global Configuration** — Framework-wide defaults
2. **Task Settings** — Class-level overrides using `settings`

!!! warning "Important"

    Task settings take precedence over global config. Settings are inherited from parent classes and can be overridden in subclasses.

## Global Configuration

Configure framework-wide defaults that apply to all tasks. These settings come with sensible defaults out of the box.

### Breakpoints

Control when `execute!` raises a `CMDx::Fault` based on task status.

```ruby
CMDx.configure do |config|
  config.task_breakpoints = "failed" # String or Array[String]
end
```

For workflows, configure which statuses halt the execution pipeline:

```ruby
CMDx.configure do |config|
  config.workflow_breakpoints = ["skipped", "failed"]
end
```

### Rollback

Control when a `rollback` of task execution is called.

```ruby
CMDx.configure do |config|
  config.rollback_on = ["failed"] # String or Array[String]
end
```

### Backtraces

Enable detailed backtraces for non-fault exceptions to improve debugging. Optionally clean up stack traces to remove framework noise.

!!! note

    In Rails environments, `backtrace_cleaner` defaults to `Rails.backtrace_cleaner.clean`.

```ruby
CMDx.configure do |config|
  # Truthy
  config.backtrace = true

  # Via callable (must respond to `call(backtrace)`)
  config.backtrace_cleaner = AdvanceCleaner.new

  # Via proc or lambda
  config.backtrace_cleaner = ->(backtrace) { backtrace[0..5] }
end
```

### Exception Handlers

Register handlers that run when non-fault exceptions occur.

!!! tip

    Use exception handlers to send errors to your APM of choice.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(task, exception)`)
  config.exception_handler = NewRelicReporter

  # Via proc or lambda
  config.exception_handler = proc do |task, exception|
    APMService.report(exception, extra_data: { task: task.name, id: task.id })
  end
end
```

### Logging

```ruby
CMDx.configure do |config|
  config.logger = CustomLogger.new($stdout)
end
```

### Middlewares

See the [Middlewares](https://github.com/drexed/cmdx/blob/main/docs/middlewares.md#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(task, options)`)
  config.middlewares.register CMDx::Middlewares::Timeout

  # Via proc or lambda
  config.middlewares.register proc { |task, options|
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.debug { "task completed in #{((end_time - start_time) * 1000).round(2)}ms" }
    result
  }

  # With options
  config.middlewares.register AuditTrailMiddleware, service_name: "document_processor"

  # Remove middleware
  config.middlewares.deregister CMDx::Middlewares::Timeout
end
```

!!! note

    Middlewares are executed in registration order. Each middleware wraps the next, creating an execution chain around task logic.

### Callbacks

See the [Callbacks](https://github.com/drexed/cmdx/blob/main/docs/callbacks.md#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via method
  config.callbacks.register :before_execution, :initialize_user_session

  # Via callable (must respond to `call(task)`)
  config.callbacks.register :on_success, LogUserActivity

  # Via proc or lambda
  config.callbacks.register :on_complete, proc { |task|
    execution_time = task.metadata[:runtime]
    Metrics.timer("task.execution_time", execution_time, tags: ["task:#{task.class.name.underscore}"])
  }

  # With options
  config.callbacks.register :on_failure, :send_alert_notification, if: :critical_task?

  # Remove callback
  config.callbacks.deregister :on_success, LogUserActivity
end
```

### Coercions

See the [Attributes - Coercions](https://github.com/drexed/cmdx/blob/main/docs/attributes/coercions.md#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.coercions.register :currency, CurrencyCoercion

  # Via method (must match signature `def coordinates_coercion(value, options)`)
  config.coercions.register :coordinates, :coordinates_coercion

  # Via proc or lambda
  config.coercions.register :tag_list, proc { |value, options|
    delimiter = options[:delimiter] || ','
    max_tags = options[:max_tags] || 50

    tags = value.to_s.split(delimiter).map(&:strip).reject(&:empty?)
    tags.first(max_tags)
  }

  # Remove coercion
  config.coercions.deregister :currency
end
```

### Validators

See the [Attributes - Validations](https://github.com/drexed/cmdx/blob/main/docs/attributes/validations.md#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.validators.register :username, UsernameValidator

  # Via method (must match signature `def url_validator(value, options)`)
  config.validators.register :url, :url_validator

  # Via proc or lambda
  config.validators.register :access_token, proc { |value, options|
    expected_prefix = options[:prefix] || "tok_"
    minimum_length = options[:min_length] || 40

    value.start_with?(expected_prefix) && value.length >= minimum_length
  }

  # Remove validator
  config.validators.deregister :username
end
```

## Task Configuration

### Settings

Override global configuration for specific tasks using `settings`:

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    # Global configuration overrides
    task_breakpoints: ["failed"],                # Breakpoint override
    workflow_breakpoints: [],                    # Breakpoint override
    backtrace: true,                             # Toggle backtrace
    backtrace_cleaner: ->(bt) { bt[0..5] },      # Backtrace cleaner
    logger: CustomLogger.new($stdout),           # Custom logger

    # Task configuration settings
    breakpoints: ["failed"],                     # Contextual pointer for :task_breakpoints and :workflow_breakpoints
    log_level: :info,                            # Log level override
    log_formatter: CMDx::LogFormatters::Json.new # Log formatter override
    tags: ["billing", "financial"],              # Logging tags
    deprecated: true,                            # Task deprecations
    retries: 3,                                  # Non-fault exception retries
    retry_on: [External::ApiError],              # List of exceptions to retry on
    retry_jitter: 1,                             # Space between retry iteration, eg: current retry num + 1
    rollback_on: ["failed", "skipped"],          # Rollback on override
  )

  def work
    # Your logic here...
  end
end
```

!!! warning "Important"

    Retries reuse the same context. By default, all `StandardError` exceptions (including faults) are retried unless you specify `retry_on` option for specific matches.

### Registrations

Register or deregister middlewares, callbacks, coercions, and validators for specific tasks:

```ruby
class SendCampaignEmail < CMDx::Task
  # Middlewares
  register :middleware, CMDx::Middlewares::Timeout
  deregister :middleware, AuditTrailMiddleware

  # Callbacks
  register :callback, :on_complete, proc { |task|
    runtime = task.metadata[:runtime]
    Analytics.track("email_campaign.sent", runtime, tags: ["task:#{task.class.name}"])
  }
  deregister :callback, :before_execution, :initialize_user_session

  # Coercions
  register :coercion, :currency, CurrencyCoercion
  deregister :coercion, :coordinates

  # Validators
  register :validator, :username, :username_validator
  deregister :validator, :url

  def work
    # Your logic here...
  end
end
```

## Configuration Management

### Access

```ruby
# Global configuration access
CMDx.configuration.logger               #=> <Logger instance>
CMDx.configuration.task_breakpoints     #=> ["failed"]
CMDx.configuration.middlewares.registry #=> [<Middleware>, ...]

# Task configuration access
class ProcessUpload < CMDx::Task
  settings(tags: ["files", "storage"])

  def work
    self.class.settings[:logger] #=> Global configuration value
    self.class.settings[:tags]   #=> Task configuration value => ["files", "storage"]
  end
end
```

### Resetting

!!! warning

    Resetting affects your entire application. Use this primarily in test environments.

```ruby
# Reset to framework defaults
CMDx.reset_configuration!

# Verify reset
CMDx.configuration.task_breakpoints     #=> ["failed"] (default)
CMDx.configuration.middlewares.registry #=> Empty registry

# Commonly used in test setup (RSpec example)
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
rails generate cmdx:task ModerateBlogPost
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/moderate_blog_post.rb
class ModerateBlogPost < CMDx::Task
  def work
    # Your logic here...
  end
end
```

!!! tip

    Use **present tense verbs + noun** for task names, eg: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`

## Type safety

CMDx includes built-in RBS (Ruby Type Signature) inline annotations throughout the codebase, providing type information for static analysis and editor support.

- **Type checking** — Catch type errors before runtime using tools like Steep or TypeProf
- **Better IDE support** — Enhanced autocomplete, navigation, and inline documentation
- **Self-documenting code** — Clear method signatures and return types
- **Refactoring confidence** — Type-aware refactoring reduces bugs

# Basics - Setup

Tasks are the heart of CMDx—self-contained units of business logic with built-in validation, error handling, and execution tracking.

## Structure

Tasks need only two things: inherit from `CMDx::Task` and define a `work` method:

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end
end
```

Without a `work` method, execution raises `CMDx::UndefinedMethodError`.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method defined
end

IncompleteTask.execute #=> raises CMDx::UndefinedMethodError
```

## Rollback

Undo any operations linked to the given status, helping to restore a pristine state.

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end

  def rollback
    # Your undo logic...
  end
end
```

## Inheritance

Share configuration across tasks using inheritance:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, SecurityMiddleware

  before_execution :initialize_request_tracking

  attribute :session_id

  private

  def initialize_request_tracking
    context.tracking_id ||= SecureRandom.uuid
  end
end

class SyncInventory < ApplicationTask
  def work
    # Your logic here...
  end
end
```

## Lifecycle

Tasks follow a predictable execution pattern:

!!! danger "Caution"

    Tasks are single-use objects. Once executed, they're frozen and immutable.

| Stage | State | Status | Description |
|-------|-------|--------|-------------|
| **Instantiation** | `initialized` | `success` | Task created with context |
| **Validation** | `executing` | `success`/`failed` | Attributes validated |
| **Execution** | `executing` | `success`/`failed`/`skipped` | `work` method runs |
| **Completion** | `executed` | `success`/`failed`/`skipped` | Result finalized |
| **Freezing** | `executed` | `success`/`failed`/`skipped` | Task becomes immutable |
| **Rollback** | `executed` | `failed`/`skipped` | Work undone |

# Basics - Execution

CMDx offers two execution methods with different error handling approaches. Choose based on your needs: safe result handling or exception-based control flow.

## Execution Methods

Both methods return results, but handle failures differently:

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `execute` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `execute!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` when skipped or failed | Exception-based control flow |

## Non-bang Execution

Always returns a `CMDx::Result`, never raises exceptions. Perfect for most use cases.

```ruby
result = CreateAccount.execute(email: "user@example.com")

# Check execution state
result.success?         #=> true/false
result.failed?          #=> true/false
result.skipped?         #=> true/false

# Access result data
result.context.email    #=> "user@example.com"
result.state            #=> "complete"
result.status           #=> "success"
```

## Bang Execution

Raises `CMDx::Fault` exceptions on failure or skip. Returns results only on success.

| Exception | Raised When |
|-----------|-------------|
| `CMDx::FailFault` | Task execution fails |
| `CMDx::SkipFault` | Task execution is skipped |

!!! warning "Important"

    Behavior depends on `task_breakpoints` or `workflow_breakpoints` config. Default: only failures raise exceptions.

```ruby
begin
  result = CreateAccount.execute!(email: "user@example.com")
  SendWelcomeEmail.execute(result.context)
rescue CMDx::FailFault => e
  ScheduleAccountRetryJob.perform_later(e.result.context.email)
rescue CMDx::SkipFault => e
  Rails.logger.info("Account creation skipped: #{e.result.reason}")
rescue Exception => e
  ErrorTracker.capture(unhandled_exception: e)
end
```

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = CreateAccount.new(email: "user@example.com", send_welcome: true)

# Access properties before execution
task.id                      #=> "abc123..." (unique task ID)
task.context.email           #=> "user@example.com"
task.context.send_welcome    #=> true
task.result.state            #=> "initialized"
task.result.status           #=> "success"

# Manual execution
task.execute
# or
task.execute!

task.result.success?         #=> true/false
```

## Result Details

The `Result` object provides comprehensive execution information:

```ruby
result = CreateAccount.execute(email: "user@example.com")

# Execution metadata
result.id           #=> "abc123..."  (unique execution ID)
result.task         #=> CreateAccount instance (frozen)
result.chain        #=> Task execution chain

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata
```

# Basics - Context

Context is your data container for inputs, intermediate values, and outputs. It makes sharing data between tasks effortless.

## Assigning Data

Context automatically captures all task inputs, normalizing keys to symbols:

```ruby
# Direct execution
CalculateShipping.execute(weight: 2.5, destination: "CA")

# Instance creation
CalculateShipping.new(weight: 2.5, "destination" => "CA")
```

!!! warning "Important"

    String keys convert to symbols automatically. Prefer symbols for consistency.

## Accessing Data

Access context data using method notation, hash keys, or safe accessors:

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Method style access (preferred)
    weight = context.weight
    destination = context.destination

    # Hash style access
    service_type = context[:service_type]
    options = context["options"]

    # Safe access with defaults
    rush_delivery = context.fetch!(:rush_delivery, false)
    carrier = context.dig(:options, :carrier)

    # Shorter alias
    cost = ctx.weight * ctx.rate_per_pound  # ctx aliases context
  end
end
```

!!! warning "Important"

    Undefined attributes return `nil` instead of raising errors—perfect for optional data.

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class CalculateShipping < CMDx::Task
  def work
    # Direct assignment
    context.carrier = Carrier.find_by(code: context.carrier_code)
    context.package = Package.new(weight: context.weight)
    context.calculated_at = Time.now

    # Hash-style assignment
    context[:status] = "calculating"
    context["tracking_number"] = "SHIP#{SecureRandom.hex(6)}"

    # Conditional assignment
    context.insurance_included ||= false

    # Batch updates
    context.merge!(
      status: "completed",
      shipping_cost: calculate_cost,
      estimated_delivery: Time.now + 3.days
    )

    # Remove sensitive data
    context.delete!(:credit_card_token)
  end

  private

  def calculate_cost
    base_rate = context.weight * context.rate_per_pound
    base_rate + (base_rate * context.tax_percentage)
  end
end
```

!!! tip

    Use context for both input values and intermediate results. This creates natural data flow through your task execution pipeline.

## Data Sharing

Share context across tasks for seamless data flow:

```ruby
# During execution
class CalculateShipping < CMDx::Task
  def work
    # Validate shipping data
    validation_result = ValidateAddress.execute(context)

    # Via context
    CalculateInsurance.execute(context)

    # Via result
    NotifyShippingCalculated.execute(validation_result)

    # Context now contains accumulated data from all tasks
    context.address_validated    #=> true (from validation)
    context.insurance_calculated #=> true (from insurance)
    context.notification_sent    #=> true (from notification)
  end
end

# After execution
result = CalculateShipping.execute(destination: "New York, NY")

CreateShippingLabel.execute(result)
```

# Basics - Chain

Chains automatically track related task executions within a thread. Think of them as execution traces that help you understand what happened and in what order.

## Management

Each thread maintains its own isolated chain using thread-local storage.

!!! warning

    Chains are thread-local. Don't share chain references across threads—it causes race conditions.

```ruby
# Thread A
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch1.csv")
  result.chain.id    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B (completely separate chain)
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch2.csv")
  result.chain.id    #=> "z3a42b95-c821-7892-b156-dd7c921fe2a3"
end

# Access current thread's chain
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current thread's chain
```

## Links

Tasks automatically create or join the current thread's chain:

!!! warning "Important"

    Chain management is automatic—no manual lifecycle handling needed.

```ruby
class ImportDataset < CMDx::Task
  def work
    # First task creates new chain
    result1 = ValidateHeaders.execute(file_path: context.file_path)
    result1.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
    result1.chain.results.size #=> 1

    # Second task joins existing chain
    result2 = SendNotification.execute(to: "admin@company.com")
    result2.chain.id == result1.chain.id  #=> true
    result2.chain.results.size            #=> 2

    # Both results reference the same chain
    result1.chain.results == result2.chain.results #=> true
  end
end
```

## Inheritance

Subtasks automatically inherit the current thread's chain, building a unified execution trail:

```ruby
class ImportDataset < CMDx::Task
  def work
    context.dataset = Dataset.find(context.dataset_id)

    # Subtasks automatically inherit current chain
    ValidateSchema.execute
    TransformData.execute!(context)
    SaveToDatabase.execute(dataset_id: context.dataset_id)
  end
end

result = ImportDataset.execute(dataset_id: 456)
chain = result.chain

# All tasks share the same chain
chain.results.size #=> 4 (main task + 3 subtasks)
chain.results.map { |r| r.task.class }
#=> [ImportDataset, ValidateSchema, TransformData, SaveToDatabase]
```

## Structure

Chains expose comprehensive execution information:

!!! warning "Important"

    Chain state reflects the first (outermost) task result. Subtasks maintain their own states.

```ruby
result = ImportDataset.execute(dataset_id: 456)
chain = result.chain

# Chain identification
chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
chain.results #=> Array of all results in execution order

# State delegation (from first/outer-most result)
chain.state   #=> "complete"
chain.status  #=> "success"
chain.outcome #=> "success"

# Access individual results
chain.results.each_with_index do |result, index|
  puts "#{index}: #{result.task.class} - #{result.status}"
end
```

# Interruptions - Halt

Stop task execution intentionally using `skip!` or `fail!`. Both methods signal clear intent about why execution stopped.

## Skipping

Use `skip!` when the task doesn't need to run. It's a no-op, not an error.

!!! warning "Important"

    Skipped tasks are considered "good" outcomes—they succeeded by doing nothing.

```ruby
class ProcessInventory < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["DISABLED_TASKS"]).include?(self.class.name)

    # With a reason
    skip!("Warehouse closed") unless Time.now.hour.between?(8, 18)

    inventory = Inventory.find(context.inventory_id)

    if inventory.already_counted?
      skip!("Inventory already counted today")
    else
      inventory.count!
    end
  end
end

result = ProcessInventory.execute(inventory_id: 456)

# Executed
result.status #=> "skipped"

# Without a reason
result.reason #=> "Unspecified"

# With a reason
result.reason #=> "Warehouse closed"
```

## Failing

Use `fail!` when the task can't complete successfully. It signals controlled, intentional failure:

```ruby
class ProcessRefund < CMDx::Task
  def work
    # Without a reason
    fail! if Array(ENV["DISABLED_TASKS"]).include?(self.class.name)

    refund = Refund.find(context.refund_id)

    # With a reason
    if refund.expired?
      fail!("Refund period has expired")
    elsif !refund.amount.positive?
      fail!("Refund amount must be positive")
    else
      refund.process!
    end
  end
end

result = ProcessRefund.execute(refund_id: 789)

# Executed
result.status #=> "failed"

# Without a reason
result.reason #=> "Unspecified"

# With a reason
result.reason #=> "Refund period has expired"
```

## Metadata Enrichment

Enrich halt calls with metadata for better debugging and error handling:

```ruby
class ProcessRenewal < CMDx::Task
  def work
    license = License.find(context.license_id)

    if license.already_renewed?
      # Without metadata
      skip!("License already renewed")
    end

    unless license.renewal_eligible?
      # With metadata
      fail!(
        "License not eligible for renewal",
        error_code: "LICENSE.NOT_ELIGIBLE",
        retry_after: Time.current + 30.days
      )
    end

    process_renewal
  end
end

result = ProcessRenewal.execute(license_id: 567)

# Without metadata
result.metadata #=> {}

# With metadata
result.metadata #=> {
                #     error_code: "LICENSE.NOT_ELIGIBLE",
                #     retry_after: <Time 30 days from now>
                #   }
```

## State Transitions

Halt methods trigger specific state and status transitions:

| Method | State | Status | Outcome |
|--------|-------|--------|---------|
| `skip!` | `interrupted` | `skipped` | `good? = true`, `bad? = true` |
| `fail!` | `interrupted` | `failed` | `good? = false`, `bad? = true` |

```ruby
result = ProcessRenewal.execute(license_id: 567)

# State information
result.state        #=> "interrupted"
result.status       #=> "skipped" or "failed"
result.interrupted? #=> true
result.complete?    #=> false

# Outcome categorization
result.good?        #=> true for skipped, false for failed
result.bad?         #=> true for both skipped and failed
```

## Execution Behavior

Halt methods behave differently depending on the call method used:

### Non-bang execution

Returns result object without raising exceptions:

```ruby
result = ProcessRefund.execute(refund_id: 789)

case result.status
when "success"
  puts "Refund processed: $#{result.context.refund.amount}"
when "skipped"
  puts "Refund skipped: #{result.reason}"
when "failed"
  puts "Refund failed: #{result.reason}"
  handle_refund_error(result.metadata[:error_code])
end
```

### Bang execution

Raises exceptions for halt conditions based on `task_breakpoints` configuration:

```ruby
begin
  result = ProcessRefund.execute!(refund_id: 789)
  puts "Success: Refund processed"
rescue CMDx::SkipFault => e
  puts "Skipped: #{e.message}"
rescue CMDx::FailFault => e
  puts "Failed: #{e.message}"
  handle_refund_failure(e.result.metadata[:error_code])
end
```

## Best Practices

Always provide a reason for better debugging and clearer exception messages:

```ruby
# Good: Clear, specific reason
skip!("Document processing paused for compliance review")
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Acceptable: Generic, non-specific reason
skip!("Paused")
fail!("Unsupported")

# Bad: Default, cannot determine reason
skip! #=> "Unspecified"
fail! #=> "Unspecified"
```

## Manual Errors

For rare cases, manually add errors before halting:

!!! warning "Important"

    Manual errors don't stop execution—you still need to call `fail!` or `skip!`.

```ruby
class ProcessRenewal < CMDx::Task
  def work
    if document.nonrenewable?
      errors.add(:document, "not renewable")
      fail!("document could not be renewed")
    else
      document.renew!
    end
  end
end
```

# Interruptions - Faults

Faults are exceptions raised by `execute!` when tasks halt. They carry rich context about execution state, enabling sophisticated error handling patterns.

## Fault Types

| Type | Triggered By | Use Case |
|------|--------------|----------|
| `CMDx::Fault` | Base class | Catch-all for any interruption |
| `CMDx::SkipFault` | `skip!` method | Optional processing, early returns |
| `CMDx::FailFault` | `fail!` method | Validation errors, processing failures |

!!! warning "Important"

    All faults inherit from `CMDx::Fault` and expose result, task, context, and chain data.

## Fault Handling

```ruby
begin
  ProcessTicket.execute!(ticket_id: 456)
rescue CMDx::SkipFault => e
  logger.info "Ticket processing skipped: #{e.message}"
  schedule_retry(e.context.ticket_id)
rescue CMDx::FailFault => e
  logger.error "Ticket processing failed: #{e.message}"
  notify_admin(e.context.assigned_agent, e.result.metadata[:error_code])
rescue CMDx::Fault => e
  logger.warn "Ticket processing interrupted: #{e.message}"
  rollback_changes
end
```

## Data Access

Access rich execution data from fault exceptions:

```ruby
begin
  LicenseActivation.execute!(license_key: key, machine_id: machine)
rescue CMDx::Fault => e
  # Result information
  e.result.state     #=> "interrupted"
  e.result.status    #=> "failed" or "skipped"
  e.result.reason    #=> "License key already activated"

  # Task information
  e.task.class       #=> <LicenseActivation>
  e.task.id          #=> "abc123..."

  # Context data
  e.context.license_key #=> "ABC-123-DEF"
  e.context.machine_id  #=> "[FILTERED]"

  # Chain information
  e.chain.id         #=> "def456..."
  e.chain.size       #=> 3
end
```

## Advanced Matching

### Task-Specific Matching

Handle faults only from specific tasks using `for?`:

```ruby
begin
  DocumentWorkflow.execute!(document_data: data)
rescue CMDx::FailFault.for?(FormatValidator, ContentProcessor) => e
  # Handle only document-related failures
  retry_with_alternate_parser(e.context)
rescue CMDx::SkipFault.for?(VirusScanner, ContentFilter) => e
  # Handle security-related skips
  quarantine_for_review(e.context.document_id)
end
```

### Custom Logic Matching

```ruby
begin
  ReportGenerator.execute!(report: report_data)
rescue CMDx::Fault.matches? { |f| f.context.data_size > 10_000 } => e
  escalate_large_dataset_failure(e)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:attempt_count] > 3 } => e
  abandon_report_generation(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "memory" } => e
  increase_memory_and_retry(e)
end
```

## Fault Propagation

Propagate failures with `throw!` to preserve context and maintain the error chain:

### Basic Propagation

```ruby
class ReportGenerator < CMDx::Task
  def work
    # Throw if skipped or failed
    validation_result = DataValidator.execute(context)
    throw!(validation_result)

    # Only throw if skipped
    check_permissions = CheckPermissions.execute(context)
    throw!(check_permissions) if check_permissions.skipped?

    # Only throw if failed
    data_result = DataProcessor.execute(context)
    throw!(data_result) if data_result.failed?

    # Continue processing
    generate_report
  end
end
```

### Additional Metadata

```ruby
class BatchProcessor < CMDx::Task
  def work
    step_result = FileValidation.execute(context)

    if step_result.failed?
      throw!(step_result, {
        batch_stage: "validation",
        can_retry: true,
        next_step: "file_repair"
      })
    end

    continue_batch
  end
end
```

## Chain Analysis

Trace fault origins and propagation through the execution chain:

```ruby
result = DocumentWorkflow.execute(invalid_data)

if result.failed?
  # Trace the original failure
  original = result.caused_failure
  if original
    puts "Original failure: #{original.task.class.name}"
    puts "Reason: #{original.reason}"
  end

  # Find what propagated the failure
  thrower = result.threw_failure
  puts "Propagated by: #{thrower.task.class.name}" if thrower

  # Analyze failure type
  case
  when result.caused_failure?
    puts "This task was the original source"
  when result.threw_failure?
    puts "This task propagated a failure"
  when result.thrown_failure?
    puts "This task failed due to propagation"
  end
end
```

# Interruptions - Exceptions

Exception handling differs between `execute` and `execute!`. Choose the method that matches your error handling strategy.

## Exception Handling

!!! warning "Important"

    Prefer `skip!` and `fail!` over raising exceptions—they signal intent more clearly.

### Non-bang execution

Captures all exceptions and returns them as failed results:

```ruby
class CompressDocument < CMDx::Task
  def work
    document = Document.find(context.document_id)
    document.compress!
  end
end

result = CompressDocument.execute(document_id: "unknown-doc-id")
result.state    #=> "interrupted"
result.status   #=> "failed"
result.failed?  #=> true
result.reason   #=> "[ActiveRecord::NotFoundError] record not found"
result.cause    #=> <ActiveRecord::NotFoundError>
```

!!! note

    Use `exception_handler` with `execute` to send exceptions to APM tools before they become failed results.

### Bang execution

Lets exceptions propagate naturally for standard Ruby error handling:

```ruby
class CompressDocument < CMDx::Task
  def work
    document = Document.find(context.document_id)
    document.compress!
  end
end

begin
  CompressDocument.execute!(document_id: "unknown-doc-id")
rescue ActiveRecord::NotFoundError => e
  puts "Handle exception: #{e.message}"
end
```

# Outcomes - Result

Results are your window into task execution. They expose everything: outcome, state, timing, context, and metadata.

## Result Attributes

Access essential execution information:

!!! warning "Important"

    Results are immutable after execution completes.

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Object data
result.task     #=> <BuildApplication>
result.context  #=> <CMDx::Context>
result.chain    #=> <CMDx::Chain>

# Execution data
result.state    #=> "interrupted"
result.status   #=> "failed"

# Fault data
result.reason   #=> "Build tool not found"
result.cause    #=> <CMDx::FailFault>
result.metadata #=> { error_code: "BUILD_TOOL.NOT_FOUND" }
```

## Lifecycle Information

Check execution state and status with predicate methods:

```ruby
result = BuildApplication.execute(version: "1.2.3")

# State predicates (execution lifecycle)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)
result.executed?    #=> true (execution finished)

# Status predicates (execution outcome)
result.success?     #=> true (successful execution)
result.failed?      #=> false (no failure)
result.skipped?     #=> false (not skipped)

# Outcome categorization
result.good?        #=> true (success or skipped)
result.bad?         #=> false (skipped or failed)
```

## Outcome Analysis

Get a unified outcome string combining state and status:

```ruby
result = BuildApplication.execute(version: "1.2.3")

result.outcome #=> "success" (state and status)
```

## Chain Analysis

Trace fault origins and propagation:

```ruby
result = DeploymentWorkflow.execute(app_name: "webapp")

if result.failed?
  # Find the original cause of failure
  if original_failure = result.caused_failure
    puts "Root cause: #{original_failure.task.class.name}"
    puts "Reason: #{original_failure.reason}"
  end

  # Find what threw the failure to this result
  if throwing_task = result.threw_failure
    puts "Failure source: #{throwing_task.task.class.name}"
    puts "Reason: #{throwing_task.reason}"
  end

  # Failure classification
  result.caused_failure?  #=> true if this result was the original cause
  result.threw_failure?   #=> true if this result threw a failure
  result.thrown_failure?  #=> true if this result received a thrown failure
end
```

## Index and Position

Results track their position within execution chains:

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Position in execution sequence
result.index #=> 0 (first task in chain)

# Access via chain
result.chain.results[result.index] == result #=> true
```

## Block Yield

Execute code with direct result access:

```ruby
BuildApplication.execute(version: "1.2.3") do |result|
  if result.success?
    notify_deployment_ready(result)
  elsif result.failed?
    handle_build_failure(result)
  else
    log_skip_reason(result)
  end
end
```

## Handlers

Handle outcomes with functional-style methods. Handlers return the result for chaining:

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Status-based handlers
result
  .handle_success { |result| notify_deployment_ready(result) }
  .handle_failed { |result| handle_build_failure(result) }
  .handle_skipped { |result| log_skip_reason(result) }

# State-based handlers
result
  .handle_complete { |result| update_build_status(result) }
  .handle_interrupted { |result| cleanup_partial_artifacts(result) }

# Outcome-based handlers
result
  .handle_good { |result| increment_success_counter(result) }
  .handle_bad { |result| alert_operations_team(result) }
```

## Pattern Matching

Use Ruby 3.0+ pattern matching for elegant outcome handling:

!!! warning "Important"

    Pattern matching works with both array and hash deconstruction.

### Array Pattern

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in ["complete", "success"]
  redirect_to build_success_page
in ["interrupted", "failed"]
  retry_build_with_backoff(result)
in ["interrupted", "skipped"]
  log_skip_and_continue
end
```

### Hash Pattern

```ruby
result = BuildApplication.execute(version: "1.2.3")

case result
in { state: "complete", status: "success" }
  celebrate_build_success
in { status: "failed", metadata: { retryable: true } }
  schedule_build_retry(result)
in { bad: true, metadata: { reason: String => reason } }
  escalate_build_error("Build failed: #{reason}")
end
```

### Pattern Guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_build_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_build_permanently_failed(result)
in { runtime: time } if time > performance_threshold
  investigate_build_performance(result)
end
```

# Outcomes - States

States track where a task is in its execution lifecycle—from creation through completion or interruption.

## Definitions

| State | Description |
| ----- | ----------- |
| `initialized` | Task created but execution not yet started. Default state for new tasks. |
| `executing` | Task is actively running its business logic. Transient state during execution. |
| `complete` | Task finished execution successfully without any interruption or halt. |
| `interrupted` | Task execution was stopped due to a fault, exception, or explicit halt. |

State-Status combinations:

| State | Status | Meaning |
| ----- | ------ | ------- |
| `initialized` | `success` | Task created, not yet executed |
| `executing` | `success` | Task currently running |
| `complete` | `success` | Task finished successfully |
| `complete` | `skipped` | Task finished by skipping execution |
| `interrupted` | `failed` | Task stopped due to failure |
| `interrupted` | `skipped` | Task stopped by skip condition |

## Transitions

!!! danger "Caution"

    States are managed automatically—never modify them manually.

```ruby
# Valid state transition flow
initialized → executing → complete    (successful execution)
initialized → executing → interrupted (skipped/failed execution)
```

## Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = ProcessVideoUpload.execute

# Individual state checks
result.initialized? #=> false (after execution)
result.executing?   #=> false (after execution)
result.complete?    #=> true (successful completion)
result.interrupted? #=> false (no interruption)

# State categorization
result.executed?    #=> true (complete OR interrupted)
```

## Handlers

Handle lifecycle events with state-based handlers. Use `handle_executed` for cleanup that runs regardless of outcome:

```ruby
result = ProcessVideoUpload.execute

# Individual state handlers
result
  .handle_complete { |result| send_upload_notification(result) }
  .handle_interrupted { |result| cleanup_temp_files(result) }
  .handle_executed { |result| log_upload_metrics(result) }
```

# Outcomes - Statuses

Statuses represent the business outcome—did the task succeed, skip, or fail? This differs from state, which tracks the execution lifecycle.

## Definitions

| Status | Description |
| ------ | ----------- |
| `success` | Task execution completed successfully with expected business outcome. Default status for all tasks. |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary. |
| `failed` | Task stopped execution due to business rule violations, validation errors, or exceptions. |

## Transitions

!!! warning "Important"

    Status transitions are final and unidirectional. Once skipped or failed, tasks can't return to success.

```ruby
# Valid status transitions
success → skipped    # via skip!
success → failed     # via fail! or exception

# Invalid transitions (will raise errors)
skipped → success    # ❌ Cannot transition
skipped → failed     # ❌ Cannot transition
failed → success     # ❌ Cannot transition
failed → skipped     # ❌ Cannot transition
```

## Predicates

Use status predicates to check execution outcomes:

```ruby
result = ProcessNotification.execute

# Individual status checks
result.success? #=> true/false
result.skipped? #=> true/false
result.failed?  #=> true/false

# Outcome categorization
result.good?    #=> true if success OR skipped
result.bad?     #=> true if skipped OR failed (not success)
```

## Handlers

Branch business logic with status-based handlers. Use `handle_good` and `handle_bad` for success/skip vs failed outcomes:

```ruby
result = ProcessNotification.execute

# Individual status handlers
result
  .handle_success { |result| mark_notification_sent(result) }
  .handle_skipped { |result| log_notification_skipped(result) }
  .handle_failed { |result| queue_retry_notification(result) }

# Outcome-based handlers
result
  .handle_good { |result| update_message_stats(result) }
  .handle_bad { |result| track_delivery_failure(result) }
```

# Attributes - Definitions

Attributes define your task's interface with automatic validation, type coercion, and accessor generation. They're the contract between callers and your business logic.

## Declarations

!!! tip

    Prefer using the `required` and `optional` alias for `attributes` for brevity and to clearly signal intent.

### Optional

Optional attributes return `nil` when not provided.

```ruby
class ScheduleEvent < CMDx::Task
  attribute :title
  attributes :duration, :location

  # Alias for attributes (preferred)
  optional :description
  optional :visibility, :attendees

  def work
    title       #=> "Team Standup"
    duration    #=> 30
    location    #=> nil
    description #=> nil
    visibility  #=> nil
    attendees   #=> ["alice@company.com", "bob@company.com"]
  end
end

# Attributes passed as keyword arguments
ScheduleEvent.execute(
  title: "Team Standup",
  duration: 30,
  attendees: ["alice@company.com", "bob@company.com"]
)
```

### Required

Required attributes must be provided in call arguments or task execution will fail.

```ruby
class PublishArticle < CMDx::Task
  attribute :title, required: true
  attributes :content, :author_id, required: true

  # Alias for attributes => required: true (preferred)
  required :category
  required :status, :tags

  def work
    title     #=> "Getting Started with Ruby"
    content   #=> "This is a comprehensive guide..."
    author_id #=> 42
    category  #=> "programming"
    status    #=> :published
    tags      #=> ["ruby", "beginner"]
  end
end

# Attributes passed as keyword arguments
PublishArticle.execute(
  title: "Getting Started with Ruby",
  content: "This is a comprehensive guide...",
  author_id: 42,
  category: "programming",
  status: :published,
  tags: ["ruby", "beginner"]
)
```

## Sources

Attributes read from any accessible object—not just context. Use sources to pull data from models, services, or any callable:

### Context

```ruby
class BackupDatabase < CMDx::Task
  # Default source is :context
  required :database_name
  optional :compression_level

  # Explicitly specify context source
  attribute :backup_path, source: :context

  def work
    database_name     #=> context.database_name
    backup_path       #=> context.backup_path
    compression_level #=> context.compression_level
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic source values:

```ruby
class BackupDatabase < CMDx::Task
  attributes :host, :credentials, source: :database_config

  # Access from declared attributes
  attribute :connection_string, source: :credentials

  def work
    # Your logic here...
  end

  private

  def database_config
    @database_config ||= DatabaseConfig.find(context.database_name)
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic source values:

```ruby
class BackupDatabase < CMDx::Task
  # Proc
  attribute :timestamp, source: proc { Time.current }

  # Lambda
  attribute :server, source: -> { Current.server }
end
```

### Class or Module

For complex source logic, use classes or modules:

```ruby
class DatabaseResolver
  def self.call(task)
    Database.find(task.context.database_name)
  end
end

class BackupDatabase < CMDx::Task
  # Class or Module
  attribute :schema, source: DatabaseResolver

  # Instance
  attribute :metadata, source: DatabaseResolver.new
end
```

## Nesting

Build complex structures with nested attributes. Children inherit their parent as source and support all attribute options:

!!! note

    Nested attributes support all features: naming, coercions, validations, defaults, and more.

```ruby
class ConfigureServer < CMDx::Task
  # Required parent with required children
  required :network_config do
    required :hostname, :port, :protocol, :subnet
    optional :load_balancer
    attribute :firewall_rules
  end

  # Optional parent with conditional children
  optional :ssl_config do
    required :certificate_path, :private_key # Only required if ssl_config provided
    optional :enable_http2, prefix: true
  end

  # Multi-level nesting
  attribute :monitoring do
    required :provider

    optional :alerting do
      required :threshold_percentage
      optional :notification_channel
    end
  end

  def work
    network_config   #=> { hostname: "api.company.com" ... }
    hostname         #=> "api.company.com"
    load_balancer    #=> nil
  end
end

ConfigureServer.execute(
  server_id: "srv-001",
  network_config: {
    hostname: "api.company.com",
    port: 443,
    protocol: "https",
    subnet: "10.0.1.0/24",
    firewall_rules: "allow_web_traffic"
  },
  monitoring: {
    provider: "datadog",
    alerting: {
      threshold_percentage: 85.0,
      notification_channel: "slack"
    }
  }
)
```

!!! warning "Important"

    Child requirements only apply when the parent is provided—perfect for optional structures.

## Error Handling

Validation failures provide detailed, structured error messages:

!!! note

    Nested attributes are only validated when their parent is present and valid.

```ruby
class ConfigureServer < CMDx::Task
  required :server_id, :environment
  required :network_config do
    required :hostname, :port
  end

  def work
    # Your logic here...
  end
end

# Missing required top-level attributes
result = ConfigureServer.execute(server_id: "srv-001")

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "environment is required. network_config is required.",
                #       messages: {
                #         environment: ["is required"],
                #         network_config: ["is required"]
                #       }
                #     }
                #   }

# Missing required nested attributes
result = ConfigureServer.execute(
  server_id: "srv-001",
  environment: "production",
  network_config: { hostname: "api.company.com" } # Missing port
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "port is required.",
                #       messages: {
                #         port: ["is required"]
                #       }
                #     }
                #   }
```

# Attributes - Naming

Customize accessor method names to avoid conflicts and improve clarity. Affixing changes only the generated methods—not the original attribute names.

!!! note

    Use naming when attributes conflict with existing methods or need better clarity in your code.

## Prefix

Adds a prefix to the generated accessor method name.

```ruby
class GenerateReport < CMDx::Task
  # Dynamic from attribute source
  attribute :template, prefix: true

  # Static
  attribute :format, prefix: "report_"

  def work
    context_template #=> "monthly_sales"
    report_format    #=> "pdf"
  end
end

# Attributes passed as original attribute names
GenerateReport.execute(template: "monthly_sales", format: "pdf")
```

## Suffix

Adds a suffix to the generated accessor method name.

```ruby
class DeployApplication < CMDx::Task
  # Dynamic from attribute source
  attribute :branch, suffix: true

  # Static
  attribute :version, suffix: "_tag"

  def work
    branch_context #=> "main"
    version_tag    #=> "v1.2.3"
  end
end

# Attributes passed as original attribute names
DeployApplication.execute(branch: "main", version: "v1.2.3")
```

## As

Completely renames the generated accessor method.

```ruby
class ScheduleMaintenance < CMDx::Task
  attribute :scheduled_at, as: :when

  def work
    when #=> <DateTime>
  end
end

# Attributes passed as original attribute names
ScheduleMaintenance.execute(scheduled_at: DateTime.new(2024, 12, 15, 2, 0, 0))
```

# Attributes - Coercions

Automatically convert inputs to expected types. Coercions handle everything from simple string-to-integer conversions to JSON parsing.

See [Global Configuration](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#coercions) for custom coercion setup.

## Usage

Define attribute types to enable automatic coercion:

```ruby
class ParseMetrics < CMDx::Task
  # Coerce into a symbol
  attribute :measurement_type, type: :symbol

  # Coerce into a rational fallback to big decimal
  attribute :value, type: [:rational, :big_decimal]

  # Coerce with options
  attribute :recorded_at, type: :date, strptime: "%m-%d-%Y"

  def work
    measurement_type #=> :temperature
    recorded_at      #=> <Date 2024-01-23>
    value            #=> 98.6 (Float)
  end
end

ParseMetrics.execute(
  measurement_type: "temperature",
  recorded_at: "01-23-2020",
  value: "98.6"
)
```

!!! tip

    Specify multiple coercion types for attributes that could be a variety of value formats. CMDx attempts each type in order until one succeeds.

## Built-in Coercions

| Type | Options | Description | Examples |
|------|---------|-------------|----------|
| `:array` | | Array conversion with JSON support | `"val"` → `["val"]`<br>`"[1,2,3]"` → `[1, 2, 3]` |
| `:big_decimal` | `:precision` | High-precision decimal | `"123.456"` → `BigDecimal("123.456")` |
| `:boolean` | | Boolean with text patterns | `"yes"` → `true`, `"no"` → `false` |
| `:complex` | | Complex numbers | `"1+2i"` → `Complex(1, 2)` |
| `:date` | `:strptime` | Date objects | `"2024-01-23"` → `Date.new(2024, 1, 23)` |
| `:datetime` | `:strptime` | DateTime objects | `"2024-01-23 10:30"` → `DateTime.new(2024, 1, 23, 10, 30)` |
| `:float` | | Floating-point numbers | `"123.45"` → `123.45` |
| `:hash` | | Hash conversion with JSON support | `'{"a":1}'` → `{"a" => 1}` |
| `:integer` | | Integer with hex/octal support | `"0xFF"` → `255`, `"077"` → `63` |
| `:rational` | | Rational numbers | `"1/2"` → `Rational(1, 2)` |
| `:string` | | String conversion | `123` → `"123"` |
| `:symbol` | | Symbol conversion | `"abc"` → `:abc` |
| `:time` | `:strptime` | Time objects | `"10:30:00"` → `Time.new(2024, 1, 23, 10, 30)` |

## Declarations

!!! warning "Important"

    Custom coercions must raise `CMDx::CoercionError` with a descriptive message.

### Proc or Lambda

Use anonymous functions for simple coercion logic:

```ruby
class TransformCoordinates < CMDx::Task
  # Proc
  register :callback, :geolocation, proc do |value, options = {}|
    begin
      Geolocation(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a geolocation"
    end
  end

  # Lambda
  register :callback, :geolocation, ->(value, options = {}) {
    begin
      Geolocation(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a geolocation"
    end
  }
end
```

### Class or Module

Register custom coercion logic for specialized type handling:

```ruby
class GeolocationCoercion
  def self.call(value, options = {})
    Geolocation(value)
  rescue StandardError
    raise CMDx::CoercionError, "could not convert into a geolocation"
  end
end

class TransformCoordinates < CMDx::Task
  register :coercion, :geolocation, GeolocationCoercion

  attribute :latitude, type: :geolocation
end
```

## Removals

Remove unwanted coercions:

!!! warning

    Each `deregister` call removes one coercion. Use multiple calls for batch removals.

```ruby
class TransformCoordinates < CMDx::Task
  deregister :coercion, :geolocation
end
```

## Error Handling

Coercion failures provide detailed error information including attribute paths, attempted types, and specific failure reasons:

```ruby
class AnalyzePerformance < CMDx::Task
  attribute  :iterations, type: :integer
  attribute  :score, type: [:float, :big_decimal]

  def work
    # Your logic here...
  end
end

result = AnalyzePerformance.execute(
  iterations: "not-a-number",
  score: "invalid-float"
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "iterations could not coerce into an integer. score could not coerce into one of: float, big_decimal.",
                #       messages: {
                #         iterations: ["could not coerce into an integer"],
                #         score: ["could not coerce into one of: float, big_decimal"]
                #       }
                #     }
                #   }
```

# Attributes - Validations

Ensure inputs meet requirements before execution. Validations run after coercions, giving you declarative data integrity checks.

See [Global Configuration](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#validators) for custom validator setup.

## Usage

Define validation rules on attributes to enforce data requirements:

```ruby
class ProcessSubscription < CMDx::Task
  # Required field with presence validation
  attribute :user_id, presence: true

  # String with length constraints
  attribute :preferences, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  attribute :tier_level, inclusion: { in: 1..5 }

  # Format validation for email
  attribute :contact_email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    user_id       #=> "98765"
    preferences   #=> "Send weekly digest emails"
    tier_level    #=> 3
    contact_email #=> "user@company.com"
  end
end

ProcessSubscription.execute(
  user_id: "98765",
  preferences: "Send weekly digest emails",
  tier_level: 3,
  contact_email: "user@company.com"
)
```

!!! tip

    Validations run after coercions, so you can validate the final coerced values rather than raw input.

## Built-in Validators

### Common Options

This list of options is available to all validators:

| Option | Description |
|--------|-------------|
| `:allow_nil` | Skip validation when value is `nil` |
| `:if` | Symbol, proc, lambda, or callable determining when to validate |
| `:unless` | Symbol, proc, lambda, or callable determining when to skip validation |
| `:message` | Custom error message for validation failures |

### Exclusion

```ruby
class ProcessProduct < CMDx::Task
  attribute :status, exclusion: { in: %w[recalled archived] }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:in` | The collection of forbidden values or range |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for discrete value exclusions |
| `:in_message` | Custom message for range-based exclusions |
| `:within_message` | Alias for :in_message option |

### Format

```ruby
class ProcessProduct < CMDx::Task
  attribute :sku, format: /\A[A-Z]{3}-[0-9]{4}\z/

  attribute :sku, format: { with: /\A[A-Z]{3}-[0-9]{4}\z/ }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `regexp` | Alias for :with option |
| `:with` | Regex pattern that the value must match |
| `:without` | Regex pattern that the value must not match |

### Inclusion

```ruby
class ProcessProduct < CMDx::Task
  attribute :availability, inclusion: { in: %w[available limited] }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:in` | The collection of allowed values or range |
| `:within` | Alias for :in option |
| `:of_message` | Custom message for discrete value inclusions |
| `:in_message` | Custom message for range-based inclusions |
| `:within_message` | Alias for :in_message option |

### Length

```ruby
class CreateBlogPost < CMDx::Task
  attribute :title, length: { within: 5..100 }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the length must fall within (inclusive) |
| `:not_within` | Range that the length must not fall within |
| `:in` | Alias for :within |
| `:not_in` | Range that the length must not fall within |
| `:min` | Minimum allowed length |
| `:max` | Maximum allowed length |
| `:is` | Exact required length |
| `:is_not` | Length that is not allowed |
| `:within_message` | Custom message for within/range validations |
| `:in_message` | Custom message for :in validation |
| `:not_within_message` | Custom message for not_within validation |
| `:not_in_message` | Custom message for not_in validation |
| `:min_message` | Custom message for minimum length validation |
| `:max_message` | Custom message for maximum length validation |
| `:is_message` | Custom message for exact length validation |
| `:is_not_message` | Custom message for is_not validation |

### Numeric

```ruby
class CreateBlogPost < CMDx::Task
  attribute :word_count, numeric: { min: 100 }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `:within` | Range that the value must fall within (inclusive) |
| `:not_within` | Range that the value must not fall within |
| `:in` | Alias for :within option |
| `:not_in` | Alias for :not_within option |
| `:min` | Minimum allowed value (inclusive, >=) |
| `:max` | Maximum allowed value (inclusive, <=) |
| `:is` | Exact value that must match |
| `:is_not` | Value that must not match |
| `:within_message` | Custom message for range validations |
| `:not_within_message` | Custom message for exclusion validations |
| `:min_message` | Custom message for minimum validation |
| `:max_message` | Custom message for maximum validation |
| `:is_message` | Custom message for exact match validation |
| `:is_not_message` | Custom message for exclusion validation |

### Presence

```ruby
class CreateBlogPost < CMDx::Task
  attribute :content, presence: true

  attribute :content, presence: { message: "cannot be blank" }

  def work
    # Your logic here...
  end
end
```

| Options | Description |
|---------|-------------|
| `true` | Ensures value is not nil, empty string, or whitespace |

## Declarations

!!! warning "Important"

    Custom validators must raise `CMDx::ValidationError` with a descriptive message.

### Proc or Lambda

Use anonymous functions for simple validation logic:

```ruby
class SetupApplication < CMDx::Task
  # Proc
  register :validator, :api_key, proc do |value, options = {}|
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  end

  # Lambda
  register :validator, :api_key, ->(value, options = {}) {
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  }
end
```

### Class or Module

Register custom validation logic for specialized requirements:

```ruby
class ApiKeyValidator
  def self.call(value, options = {})
    unless value.match?(/\A[a-zA-Z0-9]{32}\z/)
      raise CMDx::ValidationError, "invalid API key format"
    end
  end
end

class SetupApplication < CMDx::Task
  register :validator, :api_key, ApiKeyValidator

  attribute :access_key, api_key: true
end
```

## Removals

Remove unwanted validators:

!!! warning

    Each `deregister` call removes one validator. Use multiple calls for batch removals.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## Error Handling

Validation failures provide detailed, structured error messages:

```ruby
class CreateProject < CMDx::Task
  attribute :project_name, presence: true, length: { minimum: 3, maximum: 50 }
  attribute :budget, numeric: { greater_than: 1000, less_than: 1000000 }
  attribute :priority, inclusion: { in: [:low, :medium, :high] }
  attribute :contact_email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    # Your logic here...
  end
end

result = CreateProject.execute(
  project_name: "AB",           # Too short
  budget: 500,                  # Too low
  priority: :urgent,            # Not in allowed list
  contact_email: "invalid-email"    # Invalid format
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "Invalid"
result.metadata #=> {
                #     errors: {
                #       full_message: "project_name is too short (minimum is 3 characters). budget must be greater than 1000. priority is not included in the list. contact_email is invalid.",
                #       messages: {
                #         project_name: ["is too short (minimum is 3 characters)"],
                #         budget: ["must be greater than 1000"],
                #         priority: ["is not included in the list"],
                #         contact_email: ["is invalid"]
                #       }
                #     }
                #   }
```

# Attributes - Defaults

Provide fallback values for optional attributes. Defaults kick in when values aren't provided or are `nil`.

## Declarations

Defaults work seamlessly with coercions, validations, and nested attributes:

### Static Values

```ruby
class OptimizeDatabase < CMDx::Task
  attribute :strategy, default: :incremental
  attribute :level, default: "basic"
  attribute :notify_admin, default: true
  attribute :timeout_minutes, default: 30
  attribute :indexes, default: []
  attribute :options, default: {}

  def work
    strategy        #=> :incremental
    level           #=> "basic"
    notify_admin    #=> true
    timeout_minutes #=> 30
    indexes         #=> []
    options         #=> {}
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic default values:

```ruby
class ProcessAnalytics < CMDx::Task
  attribute :granularity, default: :default_granularity

  def work
    # Your logic here...
  end

  private

  def default_granularity
    Current.user.premium? ? "hourly" : "daily"
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic default values:

```ruby
class CacheContent < CMDx::Task
  # Proc
  attribute :expire_hours, default: proc { Current.tenant.cache_duration || 24 }

  # Lambda
  attribute :compression, default: -> { Current.tenant.premium? ? "gzip" : "none" }
end
```

## Coercions and Validations

Defaults follow the same coercion and validation rules as provided values:

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, default: "7", type: :integer

  # Validations
  optional :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```

# Attributes - Transformations

Modify attribute values after coercion but before validation. Perfect for normalization, formatting, and data cleanup.

## Declarations

### Symbol References

Reference instance methods by symbol for dynamic value transformations:

```ruby
class ProcessAnalytics < CMDx::Task
  attribute :options, transform: :compact_blank
end
```

### Proc or Lambda

Use anonymous functions for dynamic value transformations:

```ruby
class CacheContent < CMDx::Task
  # Proc
  attribute :expire_hours, transform: proc { |v| v * 2 }

  # Lambda
  attribute :compression, transform: ->(v) { v.to_s.upcase.strip[0..2]  }
end
```

### Class or Module

Use any object that responds to `call` for reusable transformation logic:

```ruby
class EmailNormalizer
  def call(value)
    value.to_s.downcase.strip
  end
end

class ProcessContacts < CMDx::Task
  # Class or Module
  attribute :email, transform: EmailNormalizer

  # Instance
  attribute :email, transform: EmailNormalizer.new
end
```

## Validations

Validations run on transformed values, ensuring data consistency:

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, type: :integer, transform: proc { |v| v.clamp(1, 5) }

  # Validations
  optional :frequency, transform: :downcase, inclusion: { in: %w[hourly daily weekly monthly] }
end
```

# Callbacks

Run custom logic at specific points during task execution. Callbacks have full access to task context and results, making them perfect for logging, notifications, cleanup, and more.

See [Global Configuration](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#callbacks) for framework-wide callback setup.

!!! warning "Important"

    Callbacks execute in declaration order (FIFO). Multiple callbacks of the same type run sequentially.

## Available Callbacks

Callbacks execute in a predictable lifecycle order:

```ruby
1. before_validation           # Pre-validation setup
2. before_execution            # Prepare for execution

# --- Task#work executes ---

3. on_[complete|interrupted]   # State-based (execution lifecycle)
4. on_executed                 # Always runs after work completes
5. on_[success|skipped|failed] # Status-based (business outcome)
6. on_[good|bad]               # Outcome-based (success/skip vs fail)
```

## Declarations

### Symbol References

Reference instance methods by symbol for simple callback logic:

```ruby
class ProcessBooking < CMDx::Task
  before_execution :find_reservation

  # Batch declarations (works for any type)
  on_complete :notify_guest, :update_availability

  def work
    # Your logic here...
  end

  private

  def find_reservation
    @reservation ||= Reservation.find(context.reservation_id)
  end

  def notify_guest
    GuestNotifier.call(context.guest, result)
  end

  def update_availability
    AvailabilityService.update(context.room_ids, result)
  end
end
```

### Proc or Lambda

Use anonymous functions for inline callback logic:

```ruby
class ProcessBooking < CMDx::Task
  # Proc
  on_interrupted proc { ReservationSystem.pause! }

  # Lambda
  on_complete -> { ReservationSystem.resume! }
end
```

### Class or Module

Implement reusable callback logic in dedicated modules and classes:

```ruby
class BookingConfirmationCallback
  def call(task)
    if task.result.success?
      MessagingApi.send_confirmation(task.context.guest)
    else
      MessagingApi.send_issue_alert(task.context.manager)
    end
  end
end

class ProcessBooking < CMDx::Task
  # Class or Module
  on_success BookingConfirmationCallback

  # Instance
  on_interrupted BookingConfirmationCallback.new
end
```

### Conditional Execution

Control callback execution with conditional logic:

```ruby
class MessagingPermissionCheck
  def call(task)
    task.context.guest.can?(:receive_messages)
  end
end

class ProcessBooking < CMDx::Task
  # If and/or Unless
  before_execution :notify_guest, if: :messaging_enabled?, unless: :messaging_blocked?

  # Proc
  on_failure :increment_failure, if: -> { Rails.env.production? && self.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_housekeeping, if: proc { context.rooms_need_cleaning? }

  # Class or Module
  on_complete :send_confirmation, unless: MessagingPermissionCheck

  # Instance
  on_complete :send_confirmation, if: MessagingPermissionCheck.new

  def work
    # Your logic here...
  end

  private

  def messaging_enabled?
    context.guest.messaging_preference == true
  end

  def messaging_blocked?
    context.guest.communication_status == :blocked
  end
end
```

## Callback Removal

Remove unwanted callbacks dynamically:

!!! warning "Important"

    Each `deregister` call removes one callback. Use multiple calls for batch removals.

```ruby
class ProcessBooking < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_guest

  # Class or Module (no instances)
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```

# Middlewares

Wrap task execution with middleware for cross-cutting concerns like authentication, caching, timeouts, and monitoring. Think Rack middleware, but for your business logic.

See [Global Configuration](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#middlewares) for framework-wide setup.

## Execution Order

Middleware wraps task execution in layers, like an onion:

!!! note

    First registered = outermost wrapper. They execute in registration order.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware         # 1st: outermost wrapper
  register :middleware, AuthorizationMiddleware # 2nd: middle wrapper
  register :middleware, CacheMiddleware         # 3rd: innermost wrapper

  def work
    # Your logic here...
  end
end

# Execution flow:
# 1. AuditMiddleware (before)
# 2.   AuthorizationMiddleware (before)
# 3.     CacheMiddleware (before)
# 4.       [task execution]
# 5.     CacheMiddleware (after)
# 6.   AuthorizationMiddleware (after)
# 7. AuditMiddleware (after)
```

## Declarations

### Proc or Lambda

Use anonymous functions for simple middleware logic:

```ruby
class ProcessCampaign < CMDx::Task
  # Proc
  register :middleware, proc do |task, options, &block|
    result = block.call
    Analytics.track(result.status)
    result
  end

  # Lambda
  register :middleware, ->(task, options, &block) {
    result = block.call
    Analytics.track(result.status)
    result
  }
end
```

### Class or Module

For complex middleware logic, use classes or modules:

```ruby
class TelemetryMiddleware
  def call(task, options)
    result = yield
    Telemetry.record(result.status)
  ensure
    result # Always return result
  end
end

class ProcessCampaign < CMDx::Task
  # Class or Module
  register :middleware, TelemetryMiddleware

  # Instance
  register :middleware, TelemetryMiddleware.new

  # With options
  register :middleware, MonitoringMiddleware, service_key: ENV["MONITORING_KEY"]
  register :middleware, MonitoringMiddleware.new(ENV["MONITORING_KEY"])
end
```

## Removals

Remove class or module-based middleware globally or per-task:

!!! warning

    Each `deregister` call removes one middleware. Use multiple calls for batch removals.

```ruby
class ProcessCampaign < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, TelemetryMiddleware
end
```

## Built-in

### Timeout

Prevent tasks from running too long:

```ruby
class ProcessReport < CMDx::Task
  # Default timeout: 3 seconds
  register :middleware, CMDx::Middlewares::Timeout

  # Seconds (takes Numeric, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, seconds: :max_processing_time

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, unless: -> { self.class.name.include?("Quick") }

  def work
    # Your logic here...
  end

  private

  def max_processing_time
    Rails.env.production? ? 2 : 10
  end
end

# Slow task
result = ProcessReport.execute

result.state    #=> "interrupted"
result.status   #=> "failure"
result.reason   #=> "[CMDx::TimeoutError] execution exceeded 3 seconds"
result.cause    #=> <CMDx::TimeoutError>
result.metadata #=> { limit: 3 }
```

### Correlate

Add correlation IDs for distributed tracing and request tracking:

```ruby
class ProcessExport < CMDx::Task
  # Default correlation ID generation
  register :middleware, CMDx::Middlewares::Correlate

  # Seconds (takes Object, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, id: proc { |task| task.context.session_id }

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, if: :correlation_enabled?

  def work
    # Your logic here...
  end

  private

  def correlation_enabled?
    ENV["CORRELATION_ENABLED"] == "true"
  end
end

result = ProcessExport.execute
result.metadata #=> { correlation_id: "550e8400-e29b-41d4-a716-446655440000" }
```

### Runtime

Track task execution time in milliseconds using a monotonic clock:

```ruby
class PerformanceMonitoringCheck
  def call(task)
    task.context.tenant.monitoring_enabled?
  end
end

class ProcessExport < CMDx::Task
  # Default timeout is 3 seconds
  register :middleware, CMDx::Middlewares::Runtime

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Runtime, if: PerformanceMonitoringCheck
end

result = ProcessExport.execute
result.metadata #=> { runtime: 1247 } (ms)
```

# Logging

CMDx automatically logs every task execution with structured data, making debugging and monitoring effortless. Choose from multiple formatters to match your logging infrastructure.

## Formatters

Choose the format that works best for your logging system:

| Formatter | Use Case | Output Style |
|-----------|----------|--------------|
| `Line` | Traditional logging | Single-line format |
| `Json` | Structured systems | Compact JSON |
| `KeyValue` | Log parsing | `key=value` pairs |
| `Logstash` | ELK stack | JSON with @version/@timestamp |
| `Raw` | Minimal output | Message content only |

Sample output:

```log
<!-- Success (INFO level) -->
I, [2022-07-17T18:43:15.000000 #3784] INFO -- GenerateInvoice:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="GenerateInvoice" state="complete" status="success" metadata={runtime: 187}

<!-- Skipped (WARN level) -->
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidateCustomer:
index=1 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="ValidateCustomer" state="interrupted" status="skipped" reason="Customer already validated"

<!-- Failed (ERROR level) -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CalculateTax:
index=2 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="CalculateTax"  state="interrupted" status="failed" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"}

<!-- Failed Chain -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- BillingWorkflow:
index=3 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="BillingWorkflow"  state="interrupted" status="failed" caused_failure={index: 2, class: "CalculateTax", status: "failed"} threw_failure={index: 1, class: "ValidateCustomer", status: "failed"}
```

!!! tip

    Use logging as a low-level event stream to track all tasks in a request. Combine with correlation for powerful distributed tracing.

## Structure

Every log entry includes rich metadata. Available fields depend on execution context and outcome.

### Core Fields

| Field | Description | Example |
|-------|-------------|---------|
| `severity` | Log level | `INFO`, `WARN`, `ERROR` |
| `timestamp` | ISO 8601 execution time | `2022-07-17T18:43:15.000000` |
| `pid` | Process ID | `3784` |

### Task Information

| Field | Description | Example |
|-------|-------------|---------|
| `index` | Execution sequence position | `0`, `1`, `2` |
| `chain_id` | Unique execution chain ID | `018c2b95-b764-7615...` |
| `type` | Execution unit type | `Task`, `Workflow` |
| `class` | Task class name | `GenerateInvoiceTask` |
| `id` | Unique task instance ID | `018c2b95-b764-7615...` |
| `tags` | Custom categorization | `["billing", "financial"]` |

### Execution Data

| Field | Description | Example |
|-------|-------------|---------|
| `state` | Lifecycle state | `complete`, `interrupted` |
| `status` | Business outcome | `success`, `skipped`, `failed` |
| `outcome` | Final classification | `success`, `interrupted` |
| `metadata` | Custom task data | `{order_id: 123, amount: 99.99}` |

### Failure Chain

| Field | Description |
|-------|-------------|
| `reason` | Reason given for the stoppage |
| `caused` | Cause exception details |
| `caused_failure` | Original failing task details |
| `threw_failure` | Task that propagated the failure |

## Usage

Access the framework logger directly within tasks:

```ruby
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Subscription processed")
  end
end
```

# Internationalization (i18n)

CMDx supports 90+ languages out of the box for all error messages, validations, coercions, and faults. Error messages automatically adapt to the current `I18n.locale`, making it easy to build applications for global audiences.

## Usage

All error messages are automatically localized based on your current locale:

```ruby
class ProcessQuote < CMDx::Task
  attribute :price, type: :float

  def work
    # Your logic here...
  end
end

I18n.with_locale(:fr) do
  result = ProcessQuote.execute(price: "invalid")
  result.metadata[:messages][:price] #=> ["impossible de contraindre en float"]
end
```

## Configuration

CMDx uses the `I18n` gem for localization. In Rails, locales load automatically.

### Copy Locale Files

Copy locale files to your Rails application's `config/locales` directory:

```bash
rails generate cmdx:locale [LOCALE]

# Eg: generate french locale
rails generate cmdx:locale fr
```

### Available Locales

- af - Afrikaans
- ar - Arabic
- az - Azerbaijani
- be - Belarusian
- bg - Bulgarian
- bn - Bengali
- bs - Bosnian
- ca - Catalan
- cnr - Montenegrin
- cs - Czech
- cy - Welsh
- da - Danish
- de - German
- dz - Dzongkha
- el - Greek
- en - English
- eo - Esperanto
- es - Spanish
- et - Estonian
- eu - Basque
- fa - Persian
- fi - Finnish
- fr - French
- fy - Western Frisian
- gd - Scottish Gaelic
- gl - Galician
- he - Hebrew
- hi - Hindi
- hr - Croatian
- hu - Hungarian
- hy - Armenian
- id - Indonesian
- is - Icelandic
- it - Italian
- ja - Japanese
- ka - Georgian
- kk - Kazakh
- km - Khmer
- kn - Kannada
- ko - Korean
- lb - Luxembourgish
- lo - Lao
- lt - Lithuanian
- lv - Latvian
- mg - Malagasy
- mk - Macedonian
- ml - Malayalam
- mn - Mongolian
- mr-IN - Marathi (India)
- ms - Malay
- nb - Norwegian Bokmål
- ne - Nepali
- nl - Dutch
- nn - Norwegian Nynorsk
- oc - Occitan
- or - Odia
- pa - Punjabi
- pl - Polish
- pt - Portuguese
- rm - Romansh
- ro - Romanian
- ru - Russian
- sc - Sardinian
- sk - Slovak
- sl - Slovenian
- sq - Albanian
- sr - Serbian
- st - Southern Sotho
- sv - Swedish
- sw - Swahili
- ta - Tamil
- te - Telugu
- th - Thai
- tl - Tagalog
- tr - Turkish
- tt - Tatar
- ug - Uyghur
- uk - Ukrainian
- ur - Urdu
- uz - Uzbek
- vi - Vietnamese
- wo - Wolof
- zh-CN - Chinese (Simplified)
- zh-HK - Chinese (Hong Kong)
- zh-TW - Chinese (Traditional)
- zh-YUE - Chinese (Yue)

# Retries

CMDx provides automatic retry functionality for tasks that encounter transient failures. This is essential for handling temporary issues like network timeouts, rate limits, or database locks without manual intervention.

## Basic Usage

Configure retries upto n attempts without any delay.

```ruby
class FetchExternalData < CMDx::Task
  settings retries: 3

  def work
    response = HTTParty.get("https://api.example.com/data")
    context.data = response.parsed_response
  end
end
```

When an exception occurs during execution, CMDx automatically retries up to the configured limit.

## Selective Retries

By default, CMDx retries on `StandardError` and its subclasses. Narrow this to specific exception types:

```ruby
class ProcessPayment < CMDx::Task
  settings retries: 5, retry_on: [Stripe::RateLimitError, Net::ReadTimeout]

  def work
    # Your logic here...
  end
end
```

!!! warning "Important"

    Only exceptions matching the `retry_on` configuration will trigger retries. Uncaught exceptions immediately fail the task.

## Retry Jitter

Add delays between retry attempts to avoid overwhelming external services or to implement exponential backoff strategies.

### Fixed Value

Use a numeric value to calculate linear delay (`jitter * current_retry`):

```ruby
class ImportRecords < CMDx::Task
  settings retries: 3, retry_jitter: 0.5

  def work
    # Delays: 0s, 0.5s (retry 1), 1.0s (retry 2), 1.5s (retry 3)
    context.records = ExternalAPI.fetch_records
  end
end
```

### Symbol References

Define an instance method for custom delay logic:

```ruby
class SyncInventory < CMDx::Task
  settings retries: 5, retry_jitter: :exponential_backoff

  def work
    context.inventory = InventoryAPI.sync
  end

  private

  def exponential_backoff(current_retry)
    2 ** current_retry # 2s, 4s, 8s, 16s, 32s
  end
end
```

### Proc or Lambda

Pass a proc for inline delay calculations:

```ruby
class PollJobStatus < CMDx::Task
  # Proc
  settings retries: 10, retry_jitter: proc { |retry_count| [retry_count * 0.5, 5.0].min }

  # Lambda
  settings retries: 10, retry_jitter: ->(retry_count) { [retry_count * 0.5, 5.0].min }

  def work
    # Delays: 0.5s, 1.0s, 1.5s, 2.0s, 2.5s, 3.0s, 3.5s, 4.0s, 4.5s, 5.0s (capped)
    context.status = JobAPI.check_status(context.job_id)
  end
end
```

### Class or Module

Implement reusable delay logic in dedicated modules and classes:

```ruby
class ExponentialBackoff
  def call(task, retry_count)
    base_delay = task.context.base_delay || 1.0
    [base_delay * (2 ** retry_count), 60.0].min
  end
end

class FetchUserProfile < CMDx::Task
  # Class or Module
  settings retries: 4, retry_jitter: ExponentialBackoff

  # Instance
  settings retries: 4, retry_jitter: ExponentialBackoff.new

  def work
    # Your logic here...
  end
end
```

# Task Deprecation

Manage legacy tasks gracefully with built-in deprecation support. Choose how to handle deprecated tasks—log warnings for awareness, issue Ruby warnings for development, or prevent execution entirely.

## Modes

### Raise

Prevent task execution completely. Perfect for tasks that must no longer run.

!!! warning

    Use `:raise` mode carefully—it will break existing workflows immediately.

```ruby
class ProcessObsoleteAPI < CMDx::Task
  settings(deprecated: :raise)

  def work
    # Will never execute...
  end
end

result = ProcessObsoleteAPI.execute
#=> raises CMDx::DeprecationError: "ProcessObsoleteAPI usage prohibited"
```

### Log

Allow execution while tracking deprecation in logs. Ideal for gradual migrations.

```ruby
class ProcessLegacyFormat < CMDx::Task
  settings(deprecated: :log)

  # Same
  settings(deprecated: true)

  def work
    # Executes but logs deprecation warning...
  end
end

result = ProcessLegacyFormat.execute
result.successful? #=> true

# Deprecation warning appears in logs:
# WARN -- : DEPRECATED: ProcessLegacyFormat - migrate to replacement or discontinue use
```

### Warn

Issue Ruby warnings visible during development and testing. Keeps production logs clean while alerting developers.

```ruby
class ProcessOldData < CMDx::Task
  settings(deprecated: :warn)

  def work
    # Executes but emits Ruby warning...
  end
end

result = ProcessOldData.execute
result.successful? #=> true

# Ruby warning appears in stderr:
# [ProcessOldData] DEPRECATED: migrate to a replacement or discontinue use
```

## Declarations

### Symbol or String

```ruby
class OutdatedConnector < CMDx::Task
  # Symbol
  settings(deprecated: :raise)

  # String
  settings(deprecated: "warn")
end
```

### Boolean or Nil

```ruby
class OutdatedConnector < CMDx::Task
  # Deprecates with default :log mode
  settings(deprecated: true)

  # Skips deprecation
  settings(deprecated: false)
  settings(deprecated: nil)
end
```

### Method

```ruby
class OutdatedConnector < CMDx::Task
  # Symbol
  settings(deprecated: :deprecated?)

  def work
    # Your logic here...
  end

  private

  def deprecated?
    Time.now.year > 2024 ? :raise : false
  end
end
```

### Proc or Lambda

```ruby
class OutdatedConnector < CMDx::Task
  # Proc
  settings(deprecated: proc { Rails.env.development? ? :raise : :log })

  # Lambda
  settings(deprecated: -> { Current.tenant.legacy_mode? ? :warn : :raise })
end
```

### Class or Module

```ruby
class OutdatedTaskDeprecator
  def call(task)
    task.class.name.include?("Outdated")
  end
end

class OutdatedConnector < CMDx::Task
  # Class or Module
  settings(deprecated: OutdatedTaskDeprecator)

  # Instance
  settings(deprecated: OutdatedTaskDeprecator.new)
end
```

# Workflows

Compose multiple tasks into powerful, sequential pipelines. Workflows provide a declarative way to build complex business processes with conditional execution, shared context, and flexible error handling.

## Declarations

Tasks run in declaration order (FIFO), sharing a common context across the pipeline.

!!! warning

    Don't define a `work` method in workflows—the module handles execution automatically.

### Task

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

!!! tip

    Execute tasks in parallel via the [cmdx-parallel](https://github.com/drexed/cmdx-parallel) gem.

### Group

Group related tasks to share configuration:

!!! warning "Important"

    Settings and conditionals apply to all tasks in the group.

```ruby
class ContentModerationWorkflow < CMDx::Task
  include CMDx::Workflow

  # Screening phase
  tasks ScanForProfanity, CheckForSpam, ValidateImages, breakpoints: ["skipped"]

  # Review phase
  tasks ApplyFilters, ScoreContent, FlagSuspicious

  # Decision phase
  tasks PublishContent, QueueForReview, NotifyModerators
end
```

### Conditionals

Conditionals support multiple syntaxes for flexible execution control:

```ruby
class ContentAccessCheck
  def call(task)
    task.context.user.can?(:publish_content)
  end
end

class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  # If and/or Unless
  task SendWelcomeEmail, if: :email_configured?, unless: :email_disabled?

  # Proc
  task SendWelcomeEmail, if: -> { Rails.env.production? && self.class.name.include?("Premium") }

  # Lambda
  task SendWelcomeEmail, if: proc { context.features_enabled? }

  # Class or Module
  task SendWelcomeEmail, unless: ContentAccessCheck

  # Instance
  task SendWelcomeEmail, if: ContentAccessCheck.new

  # Conditional applies to all tasks of this declaration group
  tasks SendWelcomeEmail, CreateDashboard, SetupTutorial, if: :email_configured?

  private

  def email_configured?
    context.user.email_address == true
  end

  def email_disabled?
    context.user.communication_preference == :disabled
  end
end
```

## Halt Behavior

By default, skipped tasks don't stop the workflow—they're treated as no-ops. Configure breakpoints globally or per-task to customize this behavior.

```ruby
class AnalyticsWorkflow < CMDx::Task
  include CMDx::Workflow

  task CollectMetrics      # If fails → workflow stops
  task FilterOutliers      # If skipped → workflow continues
  task GenerateDashboard   # Only runs if no failures occurred
end
```

### Task Configuration

Configure halt behavior for the entire workflow:

```ruby
class SecurityWorkflow < CMDx::Task
  include CMDx::Workflow

  # Halt on both failed and skipped results
  settings(workflow_breakpoints: ["skipped", "failed"])

  task PerformSecurityScan
  task ValidateSecurityRules
end

class OptionalTasksWorkflow < CMDx::Task
  include CMDx::Workflow

  # Never halt, always continue
  settings(breakpoints: [])

  task TryBackupData
  task TryCleanupLogs
  task TryOptimizeCache
end
```

### Group Configuration

Different task groups can have different halt behavior:

```ruby
class SubscriptionWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateSubscription, ValidatePayment, workflow_breakpoints: ["skipped", "failed"]

  # Never halt, always continue
  task SendConfirmationEmail, UpdateBilling, breakpoints: []
end
```

## Nested Workflows

Build hierarchical workflows by composing workflows within workflows:

```ruby
class EmailPreparationWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateRecipients
  task CompileTemplate
end

class EmailDeliveryWorkflow < CMDx::Task
  include CMDx::Workflow

  tasks SendEmails, TrackDeliveries
end

class CompleteEmailWorkflow < CMDx::Task
  include CMDx::Workflow

  task EmailPreparationWorkflow
  task EmailDeliveryWorkflow, if: proc { context.preparation_successful? }
  task GenerateDeliveryReport
end
```

## Parallel Execution

Run tasks concurrently using the [Parallel](https://github.com/grosser/parallel) gem. It automatically uses all available processors for maximum throughput.

!!! warning

    Context is read-only during parallel execution. Load all required data beforehand.

```ruby
class SendWelcomeNotifications < CMDx::Task
  include CMDx::Workflow

  # Default options (dynamically calculated to available processors)
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel

  # Fix number of threads
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel, in_threads: 2

  # Fix number of forked processes
  tasks SendWelcomeEmail, SendWelcomeSms, SendWelcomePush, strategy: :parallel, in_processes: 2

  # NOTE: Reactors are not supported
end
```

## Task Generator

Generate new CMDx workflow tasks quickly using the built-in generator:

```bash
rails generate cmdx:workflow SendNotifications
```

This creates a new workflow task file with the basic structure:

```ruby
# app/tasks/send_notifications.rb
class SendNotifications < CMDx::Task
  include CMDx::Workflow

  tasks Task1, Task2
end
```

!!! tip

    Use **present tense verbs + pluralized noun** for workflow task names, eg: `SendNotifications`, `DownloadFiles`, `ValidateDocuments`

# Tips and Tricks

Best practices, patterns, and techniques to build maintainable CMDx applications.

## Project Organization

### Directory Structure

Create a well-organized command structure for maintainable applications:

```text
/app/
└── /tasks/
    ├── /invoices/
    │   ├── calculate_tax.rb
    │   ├── validate_invoice.rb
    │   ├── send_invoice.rb
    │   └── process_invoice.rb # workflow
    ├── /reports/
    │   ├── generate_pdf.rb
    │   ├── compile_data.rb
    │   ├── export_csv.rb
    │   └── create_reports.rb # workflow
    ├── application_task.rb # base class
    ├── authenticate_session.rb
    └── activate_account.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Verb + Noun
class ExportData < CMDx::Task; end
class CompressFile < CMDx::Task; end
class ValidateSchema < CMDx::Task; end

# Use present tense verbs for actions
class GenerateToken < CMDx::Task; end      # ✓ Good
class GeneratingToken < CMDx::Task; end    # ❌ Avoid
class TokenGeneration < CMDx::Task; end    # ❌ Avoid
```

### Story Telling

Break down complex logic into descriptive methods that read like a narrative:

```ruby
class ProcessOrder < CMDx::Task
  def work
    charge_payment_method
    assign_to_warehouse
    send_notification
  end

  private

  def charge_payment_method
    order.primary_payment_method.charge!
  end

  def assign_to_warehouse
    order.ready_for_shipping!
  end

  def send_notification
    if order.products_out_of_stock?
      OrderMailer.pending(order).deliver
    else
      OrderMailer.preparing(order).deliver
    end
  end
end
```

### Style Guide

Follow this order for consistent, readable tasks:

```ruby
class ExportReport < CMDx::Task

  # 1. Register functions
  register :middleware, CMDx::Middlewares::Correlate
  register :validator, :format, FormatValidator

  # 2. Define callbacks
  before_execution :find_report
  on_complete :track_export_metrics, if: ->(task) { Current.tenant.analytics? }

  # 3. Declare attributes
  attributes :user_id
  required :report_id
  optional :format_type

  # 4. Define work method
  def work
    report.compile!
    report.export!

    context.exported_at = Time.now
  end

  # TIP: Favor private business logic to reduce the surface of the public API.
  private

  # 5. Build helper functions
  def find_report
    @report ||= Report.find(report_id)
  end

  def track_export_metrics
    Analytics.increment(:report_exported)
  end

end
```

## Attribute Options

Use `with_options` to reduce duplication:

```ruby
class ConfigureCompany < CMDx::Task
  # Apply common options to multiple attributes
  with_options(type: :string, presence: true) do
    attributes :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
    required :company_name, :industry
    optional :description, format: { with: /\A[\w\s\-\.,!?]+\z/ }
  end

  # Nested attributes with shared prefix
  required :headquarters do
    with_options(prefix: :hq_) do
      attributes :street, :city, :zip_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :region, type: :string
    end
  end

  def work
    # Your logic here...
  end
end
```

## More Examples

- [Active Record Query Tagging](https://github.com/drexed/cmdx/blob/main/examples/active_record_query_tagging.md)
- [Paper Trail Whatdunnit](https://github.com/drexed/cmdx/blob/main/examples/paper_trail_whatdunnit.md)
- [Stoplight Circuit Breaker](https://github.com/drexed/cmdx/blob/main/examples/stoplight_circuit_breaker.md)

