# CMDx Documentation

This file contains all the CMDx documentation consolidated from the docs directory.

---

url: https://github.com/drexed/cmdx/blob/main/docs/getting_started.md
---

# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic attribute validation, structured error handling, comprehensive logging, and intelligent execution flow control.

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

CMDx follows a two-tier configuration hierarchy:

1. **Global Configuration**: Framework-wide defaults
2. **Task Settings**: Class-level overrides via `settings`

> [!IMPORTANT]
> Task-level settings take precedence over global configuration. Settings are inherited from superclasses and can be overridden in subclasses.

## Global Configuration

Global configuration settings apply to all tasks inherited from `CMDx::Task`.
Globally these settings are initialized with sensible defaults.

### Breakpoints

Breakpoints control when `execute!` raises faults.

```ruby
CMDx.configure do |config|
  config.task_breakpoints = "skipped"
  config.workflow_breakpoints = ["skipped", "failed"]
end
```

### Logging

```ruby
CMDx.configure do |config|
  config.logger = CustomLogger.new($stdout)
end
```

### Middlewares

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

> [!NOTE]
> Middlewares are executed in registration order. Each middleware wraps the next, creating an execution chain around task logic.

### Callbacks

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
    logger: CustomLogger.new($stdout),           # Custom logger

    # Task configuration settings
    breakpoints: ["failed"],                     # Contextual pointer for :task_breakpoints and :workflow_breakpoints
    log_level: :info,                            # Log level override
    log_formatter: CMDx::LogFormatters::Json.new # Log formatter override
    tags: ["billing", "financial"],              # Logging tags
    deprecated: true                             # Task deprecations
  )

  def work
    # Your logic here...
  end
end
```

> [!TIP]
> Use task-level settings for tasks that require special handling, such as financial reporting, external API integrations, or critical system operations.

### Registrations

Register middlewares, callbacks, coercions, and validators on a specific task.
Deregister options that should not be available.

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

> [!WARNING]
> Resetting configuration affects the entire application. Use primarily in test environments or during application initialization.

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

> [!TIP]
> Use **present tense verbs + noun** for task names, eg: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md
---

# Basics - Setup

Tasks are the core building blocks of CMDx, encapsulating business logic within structured, reusable objects. Each task represents a unit of work with automatic attribute validation, error handling, and execution tracking.

## Structure

Tasks inherit from `CMDx::Task` and require only a `work` method:

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end
end
```

An exception will be raised if a work method is not defined.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method defined
end

IncompleteTask.execute #=> raises CMDx::UndefinedMethodError
```

## Inheritance

All configuration options are inheritable by any child classes.
Create a base class to share common configuration across tasks:

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

Tasks follow a predictable call pattern with specific states and statuses:

> [!CAUTION]
> Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.

| Stage | State | Status | Description |
|-------|-------|--------|-------------|
| **Instantiation** | `initialized` | `success` | Task created with context |
| **Validation** | `executing` | `success`/`failed` | Attributes validated |
| **Execution** | `executing` | `success`/`failed`/`skipped` | `work` method runs |
| **Completion** | `executed` | `success`/`failed`/`skipped` | Result finalized |
| **Freezing** | `executed` | `success`/`failed`/`skipped` | Task becomes immutable |

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/execution.md
---

# Basics - Execution

Task execution in CMDx provides two distinct methods that handle success and halt scenarios differently. Understanding when to use each method is crucial for proper error handling and control flow in your application workflows.

## Methods Overview

Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.
Create a new instance for subsequent executions.

| Method | Returns | Exceptions | Use Case |
|--------|---------|------------|----------|
| `execute` | Always returns `CMDx::Result` | Never raises | Predictable result handling |
| `execute!` | Returns `CMDx::Result` on success | Raises `CMDx::Fault` when skipped or failed | Exception-based control flow |

## Non-bang Execution

The `execute` method always returns a `CMDx::Result` object regardless of execution outcome.
This is the preferred method for most use cases.

Any unhandled exceptions will be caught and returned as a task failure.

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

The bang `execute!` method raises a `CMDx::Fault` based exception when tasks fail or are skipped, and returns a `CMDx::Result` object only on success.

It raises any unhandled non-fault exceptions caused during execution.

| Exception | Raised When |
|-----------|-------------|
| `CMDx::FailFault` | Task execution fails |
| `CMDx::SkipFault` | Task execution is skipped |

> [!IMPORTANT]
> `execute!` behavior depends on the `task_breakpoints` or `workflow_breakpoints` configuration. By default, it raises exceptions only on failures.

```ruby
begin
  result = CreateAccount.execute!(email: "user@example.com")
  SendWelcomeEmail.execute(result.context)
rescue CMDx::Fault => e
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
result.status                #=> "success"

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/context.md
---

# Basics - Context

Task context provides flexible data storage, access, and sharing within task execution. It serves as the primary data container for all task inputs, intermediate results, and outputs.

## Assigning Data

Context is automatically populated with all inputs passed to a task. All keys are normalized to symbols for consistent access:

```ruby
# Direct execution
CalculateShipping.execute(weight: 2.5, destination: "CA")

# Instance creation
CalculateShipping.new(weight: 2.5, "destination" => "CA")
```

> [!IMPORTANT]
> String keys are automatically converted to symbols. Use symbols for consistency in your code.

## Accessing Data

Context provides multiple access patterns with automatic nil safety:

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

> [!IMPORTANT]
> Accessing undefined context attributes returns `nil` instead of raising errors, enabling graceful handling of optional attributes.

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

> [!TIP]
> Use context for both input values and intermediate results. This creates natural data flow through your task execution pipeline.

## Data Sharing

Context enables seamless data flow between related tasks in complex workflows:

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/chain.md
---

# Basics - Chain

Chains automatically group related task executions within a thread, providing unified tracking, correlation, and execution context management. Each thread maintains its own chain through thread-local storage, eliminating the need for manual coordination.

## Management

Each thread maintains its own chain context through thread-local storage, providing automatic isolation without manual coordination.

> [!WARNING]
> Chain operations are thread-local. Never share chain references across threads as this can lead to race conditions and data corruption.

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

Every task execution automatically creates or joins the current thread's chain:

> [!IMPORTANT]
> Chain creation is automatic and transparent. You don't need to manually manage chain lifecycle.

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

When tasks call subtasks within the same thread, all executions automatically inherit the current chain, creating a unified execution trail.

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

Chains provide comprehensive execution information with state delegation:

> [!IMPORTANT]
> Chain state always reflects the first (outer-most) task result, not individual subtask outcomes. Subtasks maintain their own success/failure states.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md
---

# Interruptions - Halt

Halting stops task execution with explicit intent signaling. Tasks provide two primary halt methods that control execution flow and result in different outcomes.

## Skipping

The `skip!` method indicates a task did not meet criteria to continue execution. This represents a controlled, intentional interruption where the task determines that execution is not necessary or appropriate.

> [!IMPORTANT]
> Skipping is not a failure or error. Skipped tasks are considered successful outcomes.

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
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Warehouse closed"
```

## Failing

The `fail!` method indicates a task encountered an error condition that prevents successful completion. This represents controlled failure where the task explicitly determines that execution cannot continue.

```ruby
class ProcessRefund < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["DISABLED_TASKS"]).include?(self.class.name)

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
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Refund period has expired"
```

## Metadata Enrichment

Both halt methods accept metadata to provide additional context about the interruption. Metadata is stored as a hash and becomes available through the result object.

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

Always try to provide a `reason` when using halt methods. This provides clear context for debugging and creates meaningful exception messages.

```ruby
# Good: Clear, specific reason
skip!("Document processing paused for compliance review")
fail!("File format not supported by processor", code: "FORMAT_UNSUPPORTED")

# Acceptable: Generic, non-specific reason
skip!("Paused")
fail!("Unsupported")

# Bad: Default, cannot determine reason
skip! #=> "no reason given"
fail! #=> "no reason given"

---

url: https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md
---

# Interruptions - Faults

Faults are exception mechanisms that halt task execution via `skip!` and `fail!` methods. When tasks execute with the `execute!` method, fault exceptions matching the task's interruption status are raised, enabling sophisticated exception handling and control flow patterns.

## Fault Types

| Type | Triggered By | Use Case |
|------|--------------|----------|
| `CMDx::Fault` | Base class | Catch-all for any interruption |
| `CMDx::SkipFault` | `skip!` method | Optional processing, early returns |
| `CMDx::FailFault` | `fail!` method | Validation errors, processing failures |

> [!IMPORTANT]
> All fault exceptions inherit from `CMDx::Fault` and provide access to the complete task execution context including result, task, context, and chain information.

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

Faults provide comprehensive access to execution context, eg:

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

Use `for?` to handle faults only from specific task classes, enabling targeted exception handling in complex workflows.

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

Use `throw!` to propagate failures while preserving fault context and maintaining the error chain for debugging.

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

Results provide methods to analyze fault propagation and identify original failure sources in complex execution chains.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md
---

# Interruptions - Exceptions

CMDx provides robust exception handling that differs between the `execute` and `execute!` methods. Understanding how unhandled exceptions are processed is crucial for building reliable task execution flows and implementing proper error handling strategies.

## Exception Handling

> [!IMPORTANT]
> When designing tasks, try not to `raise` your own exceptions directly. Instead, use skip! or fail! to signal intent clearly. skip! communicates that the task was intentionally bypassed, while fail! marks it as an expected failure with proper handling. This keeps workflows observable, predictable, and easier to debug.

### Non-bang execution

The `execute` method captures **all** unhandled exceptions and converts them to failed results, ensuring predictable behavior and consistent result processing.

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

### Bang execution

The `execute!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md
---

# Outcomes - Result

The result object is the comprehensive return value of task execution, providing complete information about the execution outcome, state, timing, and any data produced during the task lifecycle. Results serve as the primary interface for inspecting task execution outcomes and chaining task operations.

## Result Attributes

Every result provides access to essential execution information:

> [!IMPORTANT]
> Result objects are immutable after task execution completes and reflect the final state.

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

Results provide comprehensive methods for checking execution state and status:

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

Results provide unified outcome determination depending on the fault causal chain:

```ruby
result = BuildApplication.execute(version: "1.2.3")

result.outcome #=> "success" (state and status)
```

## Chain Analysis

Use these methods to trace the root cause of faults or trace the cause points.

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

## Handlers

Use result handlers for clean, functional-style conditional logic. Handlers return the result object, enabling method chaining and fluent interfaces.

```ruby
result = BuildApplication.execute(version: "1.2.3")

# Status-based handlers
result
  .on_success { |result| notify_deployment_ready(result) }
  .on_failed { |result| handle_build_failure(result) }
  .on_skipped { |result| log_skip_reason(result) }

# State-based handlers
result
  .on_complete { |result| update_build_status(result) }
  .on_interrupted { |result| cleanup_partial_artifacts(result) }

# Outcome-based handlers
result
  .on_good { |result| increment_success_counter(result) }
  .on_bad { |result| alert_operations_team(result) }
```

## Pattern Matching

Results support Ruby's pattern matching through array and hash deconstruction:

> [!IMPORTANT]
> Pattern matching requires Ruby 3.0+

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md
---

# Outcomes - States

States represent the execution lifecycle condition of task execution, tracking
the progress of tasks through their complete execution journey. States provide
insight into where a task is in its lifecycle and enable lifecycle-based
decision making and monitoring.

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

> [!CAUTION]
> States are automatically managed during task execution and should **never** be modified manually. State transitions are handled internally by the CMDx framework.

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

Use state-based handlers for lifecycle event handling. The `on_executed` handler is particularly useful for cleanup operations that should run regardless of success, skipped, or failure.

```ruby
result = ProcessVideoUpload.execute

# Individual state handlers
result
  .on_complete { |result| send_upload_notification(result) }
  .on_interrupted { |result| cleanup_temp_files(result) }
  .on_executed { |result| log_upload_metrics(result) }
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md
---

# Outcomes - Statuses

Statuses represent the business outcome of task execution logic, indicating how the task's business logic concluded. Statuses differ from execution states by focusing on the business outcome rather than the technical execution lifecycle. Understanding statuses is crucial for implementing proper business logic branching and error handling.

## Definitions

| Status | Description |
| ------ | ----------- |
| `success` | Task execution completed successfully with expected business outcome. Default status for all tasks. |
| `skipped` | Task intentionally stopped execution because conditions weren't met or continuation was unnecessary. |
| `failed` | Task stopped execution due to business rule violations, validation errors, or exceptions. |

## Transitions

> [!IMPORTANT]
> Status transitions are unidirectional and final. Once a task is marked as skipped or failed, it cannot return to success status. Design your business logic accordingly.

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

Use status-based handlers for business logic branching. The `on_good` and `on_bad` handlers are particularly useful for handling success/skip vs failed outcomes respectively.

```ruby
result = ProcessNotification.execute

# Individual status handlers
result
  .on_success { |result| mark_notification_sent(result) }
  .on_skipped { |result| log_notification_skipped(result) }
  .on_failed { |result| queue_retry_notification(result) }

# Outcome-based handlers
result
  .on_good { |result| update_message_stats(result) }
  .on_bad { |result| track_delivery_failure(result) }
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/definitions.md
---

# Attributes - Definitions

Attributes define the interface between task callers and implementation, enabling automatic validation, type coercion, and method generation. They provide a contract to verify that task execution arguments match expected requirements and structure.

## Declarations

> [!TIP]
> Prefer using the `required` and `optional` alias for `attributes` for brevity and to clearly signal intent.

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

Attributes delegate to accessible objects within the task. The default source is `:context`, but any accessible method or object can serve as an attribute source.

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

Nested attributes enable complex attribute structures where child attributes automatically inherit their parent as the source. This allows validation and access of structured data.

> [!NOTE]
> All options available to top-level attributes are available to nested attributes, eg: naming, coercions, and validations

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

> [!IMPORTANT]
> Child attributes are only required when their parent attribute is provided, enabling flexible optional structures.

## Error Handling

Attribute validation failures result in structured error information with details about each failed attribute.

> [!NOTE]
> Nested attributes are only ever evaluated when the parent attribute is available and valid.

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
result.reason   #=> "environment is required. network_config is required."
result.metadata #=> {
                #     messages: {
                #       environment: ["is required"],
                #       network_config: ["is required"]
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
result.reason   #=> "port is required."
result.metadata #=> {
                #     messages: {
                #       port: ["is required"]
                #     }
                #   }

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/naming.md
---

# Attributes - Naming

Attribute naming provides method name customization to prevent conflicts and enable flexible attribute access patterns. When attributes share names with existing methods or when multiple attributes from different sources have the same name, affixing ensures clean method resolution within tasks.

> [!NOTE]
> Affixing modifies only the generated accessor method names within tasks.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/coercions.md
---

# Attributes - Coercions

Attribute coercions automatically convert task arguments to expected types, ensuring type safety while providing flexible input handling. Coercions transform raw input values into the specified types, supporting simple conversions like string-to-integer and complex operations like JSON parsing.

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

> [!TIP]
> Specify multiple coercion types for attributes that could be a variety of value formats. CMDx attempts each type in order until one succeeds.

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

> [!IMPORTANT]
> Coercions must raise a CMDx::CoercionError and its message is used as part of the fault reason and metadata.

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

Remove custom coercions when no longer needed:

> [!WARNING]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

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
result.reason   #=> "iterations could not coerce into an integer. score could not coerce into one of: float, big_decimal."
result.metadata #=> {
                #     messages: {
                #       iterations: ["could not coerce into an integer"],
                #       score: ["could not coerce into one of: float, big_decimal"]
                #     }
                #   }

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/validations.md
---

# Attributes - Validations

Attribute validations ensure task arguments meet specified requirements before execution begins. Validations run after coercions and provide declarative rules for data integrity, supporting both built-in validators and custom validation logic.

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

> [!TIP]
> Validations run after coercions, so you can validate the final coerced values rather than raw input.

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

> [!IMPORTANT]
> Custom validators must raise a `CMDx::ValidationError` and its message is used as part of the fault reason and metadata.

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

Remove custom validators when no longer needed:

> [!WARNING]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class SetupApplication < CMDx::Task
  deregister :validator, :api_key
end
```

## Error Handling

Validation failures provide detailed error information including attribute paths, validation rules, and specific failure reasons:

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
result.reason   #=> "project_name is too short (minimum is 3 characters). budget must be greater than 1000. priority is not included in the list. contact_email is invalid."
result.metadata #=> {
                #     messages: {
                #       project_name: ["is too short (minimum is 3 characters)"],
                #       budget: ["must be greater than 1000"],
                #       priority: ["is not included in the list"],
                #       contact_email: ["is invalid"]
                #     }
                #   }
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/defaults.md
---

# Attributes - Defaults

Attribute defaults provide fallback values when arguments are not provided or resolve to `nil`. Defaults ensure tasks have sensible values for optional attributes while maintaining flexibility for callers to override when needed.

## Declarations

Defaults apply when attributes are not provided or resolve to `nil`. They work seamlessly with coercion, validation, and nested attributes.

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

Defaults are subject to the same coercion and validation rules as provided values, ensuring consistency and catching configuration errors early.

```ruby
class ScheduleBackup < CMDx::Task
  # Coercions
  attribute :retention_days, default: "7", type: :integer

  # Validations
  optional :frequency, default: "daily", inclusion: { in: %w[hourly daily weekly monthly] }
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/callbacks.md
---

# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

> [!IMPORTANT]
> Callbacks execute in the order they are declared within each hook type. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

## Available Callbacks

Callbacks execute in precise lifecycle order. Here is the complete execution sequence:

```ruby
1. before_validation           # Pre-validation setup
2. before_execution            # Setup and preparation

# --- Task#work executed ---

3. on_[complete|interrupted]   # Based on execution state
4. on_executed                 # Task finished (any outcome)
5. on_[success|skipped|failed] # Based on execution status
6. on_[good|bad]               # Based on outcome classification
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
  on_interrupted proc { |task| ReservationSystem.pause! }

  # Lambda
  on_complete -> { ReservationSystem.resume! }
end
```

### Class or Module

Implement reusable callback logic in dedicated classes:

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
  on_failure :increment_failure, if: ->(task) { Rails.env.production? && task.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_housekeeping, if: proc { |task| task.context.rooms_need_cleaning? }

  # Class or Module
  on_complete :send_confirmation, unless: MessagingPermissionCheck

  # Instance
  on_complete :send_confirmation, if: MessagingPermissionCheck.new

  def work
    # Your logic here...
  end

  private

  def messaging_enabled?
    context.guest.messaging_preference.present?
  end

  def messaging_blocked?
    context.guest.communication_status == :blocked
  end
end
```

## Callback Removal

Remove callbacks at runtime for dynamic behavior control:

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class ProcessBooking < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_guest

  # Class or Module (no instances)
  deregister :callback, :on_complete, BookingConfirmationCallback
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/middlewares.md
---

# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

## Order

Middleware executes in a nested fashion, creating an onion-like execution pattern:

> [!NOTE]
> Middleware executes in the order they are registered, with the first registered middleware being the outermost wrapper.

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

Class and Module based declarations can be removed at a global and task level.

> [!WARNING]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

```ruby
class ProcessCampaign < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, TelemetryMiddleware
end
```

## Built-in

### Timeout

Ensures task execution doesn't exceed a specified time limit:

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

Tags tasks with a global correlation ID for distributed tracing:

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

The runtime middleware tags tasks with how long it took to execute the task.
The calculation uses a monotonic clock and the time is returned in milliseconds.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/logging.md
---

# Logging

CMDx provides comprehensive automatic logging for task execution with structured data, customizable formatters, and intelligent severity mapping. All task results are logged after completion with rich metadata for debugging and monitoring.

## Formatters

CMDx supports multiple log formatters to integrate with various logging systems:

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
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task"
class="GenerateInvoice" state="complete" status="success" metadata={runtime: 187}

<!-- Skipped (WARN level) -->
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidateCustomer:
index=1 state="interrupted" status="skipped" reason="Customer already validated"

<!-- Failed (ERROR level) -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CalculateTax:
index=2 state="interrupted" status="failed" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"}

<!-- Failed Chain -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- BillingWorkflow:
caused_failure={index: 2, class: "CalculateTax", status: "failed"}
threw_failure={index: 1, class: "ValidateCustomer", status: "failed"}
```

> [!TIP]
> Logging can be used as low-level eventing system, ingesting all tasks performed within a small action or long running request. This ie where correlation is especially handy.

## Structure

All log entries include comprehensive execution metadata. Field availability depends on execution context and outcome.

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

Tasks have access to the frameworks logger.

```ruby
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Subscription processed")
  end
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/internationalization.md
---

# Internationalization (i18n)

CMDx provides comprehensive internationalization support for all error messages, attribute validation failures, coercion errors, and fault messages. All user-facing text is automatically localized based on the current `I18n.locale`, ensuring your applications can serve global audiences with native-language error reporting.

## Localization

> [!NOTE]
> CMDx automatically localizes all error messages based on the `I18n.locale` setting.

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/deprecation.md
---

# Task Deprecation

Task deprecation provides a systematic approach to managing legacy tasks in CMDx applications. The deprecation system enables controlled migration paths by issuing warnings, logging messages, or preventing execution of deprecated tasks entirely, helping teams maintain code quality while providing clear upgrade paths.

## Modes

### Raise

`:raise` mode prevents task execution entirely. Use this for tasks that should no longer be used under any circumstances.

> [!WARNING]
> Use `:raise` mode carefully in production environments as it will break existing workflows immediately.

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

`:log` mode allows continued usage while tracking deprecation warnings. Perfect for gradual migration scenarios where immediate replacement isn't feasible.

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

`:warn` mode issues Ruby warnings visible in development and testing environments. Useful for alerting developers without affecting production logging.

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
# [ProcessOldData] DEPRECATED: migrate to replacement or discontinue use
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

---

url: https://github.com/drexed/cmdx/blob/main/docs/workflows.md
---

# Workflows

Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business logic from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

## Declarations

Tasks execute in declaration order (FIFO). The workflow context propagates to each task, allowing access to data from previous executions.

> [!IMPORTANT]
> Do **NOT** define a `work` method in workflow tasks. The included module automatically provides the execution logic.

### Task

```ruby
class OnboardingWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUserProfile
  task SetupAccountPreferences

  tasks SendWelcomeEmail, SendWelcomeSms, CreateDashboard
end
```

### Group

Group related tasks for better organization and shared configuration:

> [!IMPORTANT]
> Settings and conditionals for a group apply to all tasks within that group.

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
  task SendWelcomeEmail, if: ->(workflow) { Rails.env.production? && workflow.class.name.include?("Premium") }

  # Lambda
  task SendWelcomeEmail, if: proc { |workflow| workflow.context.features_enabled? }

  # Class or Module
  task SendWelcomeEmail, unless: ContentAccessCheck

  # Instance
  task SendWelcomeEmail, if: ContentAccessCheck.new

  # Conditional applies to all tasks of this declaration group
  tasks SendWelcomeEmail, CreateDashboard, SetupTutorial, if: :email_configured?

  private

  def email_configured?
    context.user.email_address.present?
  end

  def email_disabled?
    context.user.communication_preference == :disabled
  end
end
```

## Halt Behavior

By default skipped tasks are considered no-op executions and does not stop workflow execution.
This is configurable via global and task level breakpoint settings. Task and group configurations
can be used together within a workflow.

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

Workflows can task other workflows for hierarchical composition:

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

---

url: https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md
---

# Tips and Tricks

This guide covers advanced patterns and optimization techniques for getting the most out of CMDx in production applications.

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

### Style Guide

Follow a style pattern for consistent task design:

```ruby
class ExportReport < CMDx::Task

  # 1. Register functions
  register :middleware, CMDx::Middlewares::Correlate
  register :validator, :format, FormatValidator

  # 2. Define callbacks
  before_execution :find_report
  on_complete :track_export_metrics, if: ->(task) { Current.tenant.analytics? }

  # 3. Define attributes
  attributes :user_id
  required :report_id
  optional :format_type

  # 4. Define work
  def work
    report.compile!
    report.export!

    context.exported_at = Time.now
  end

  private

  # 5. Define methods
  def find_report
    @report ||= Report.find(report_id)
  end

  def track_export_metrics
    Analytics.increment(:report_exported)
  end

end
```

## Attribute Options

Use Rails `with_options` to reduce duplication and improve readability:

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

## ActiveRecord Query Tagging

Automatically tag SQL queries for better debugging:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class
config.active_record.query_log_tags << :cmdx_chain_id

# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  before_execution :set_execution_context

  private

  def set_execution_context
    # NOTE: This could easily be made into a middleware
    ActiveSupport::ExecutionContext.set(
      cmdx_task_class: self.class.name,
      cmdx_chain_id: chain.id
    )
  end
end

# SQL queries will now include comments like:
# /*cmdx_task_class:ExportReportTask,cmdx_chain_id:018c2b95-b764-7615*/ SELECT * FROM reports WHERE id = 1
```

---
