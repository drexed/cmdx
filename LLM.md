# CMDx Documentation

This file contains all documentation from the CMDx project, organized for easy consumption by LLMs and other tools.

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
> Task-level settings take precedence over global configuration.
> Settings are inherited from superclasses and can be overridden in subclasses.

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
    start = Time.now
    result = yield
    finish = Time.now
    Rails.logger.debug { "task complete in #{finish - start}ms" }
    result
  }

  # With options
  config.middlewares.register MetricsMiddleware, namespace: "app.tasks"

  # Remove middleware
  config.middlewares.deregister CMDx::Middlewares::Timeout
end
```

> [!NOTE]
> Middlewares are executed in registration order. Each middleware wraps the next,
> creating an execution chain around task logic.

### Callbacks

```ruby
CMDx.configure do |config|
  # Via method
  config.callbacks.register :before_execution, :setup_request_context

  # Via callable (must respond to `call(task)`)
  config.callbacks.register :on_success, TrackSuccessfulPurchase

  # Via proc or lambda
  config.callbacks.register :on_complete, proc { |task|
    duration = task.metadata[:runtime]
    StatsD.histogram("task.duration", duration, tags: ["class:#{task.class.name}"])
  }

  # With options
  config.callbacks.register :on_failure, :notify_admin, if: :production?

  # Remove callback
  config.callbacks.deregister :on_success, TrackSuccessfulPurchase
end
```

### Coercions

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.coercions.register :money, MoneyCoercion

  # Via method (must match signature `def point_coercion(value, options)`)
  config.coercions.register :point, :point_coercion

  # Via proc or lambda
  config.coercions.register :csv_array, proc { |value, options|
    separator = options[:separator] || ','
    max_items = options[:max_items] || 100

    items = value.to_s.split(separator).map(&:strip).reject(&:empty?)
    items.first(max_items)
  }

  # Remove coercion
  config.coercions.deregister :money
end
```

### Validators

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.validators.register :email, EmailValidator

  # Via method (must match signature `def phone_validator(value, options)`)
  config.validators.register :phone, :phone_validator

  # Via proc or lambda
  config.validators.register :api_key, proc { |value, options|
    required_prefix = options[:prefix] || "sk_"
    min_length = options[:min_length] || 32

    value.start_with?(required_prefix) && value.length >= min_length
  }

  # Remove validator
  config.validators.deregister :email
end
```

## Task Configuration

### Settings

Override global configuration for specific tasks using `settings`:

```ruby
class ProcessPayment < CMDx::Task
  settings(
    # Global configuration overrides
    task_breakpoints: ["failed"],                # Breakpoint override
    workflow_breakpoints: [],                    # Breakpoint override
    logger: CustomLogger.new($stdout),           # Custom logger

    # Task configuration settings
    breakpoints: ["failed"],                     # Contextual pointer for :task_breakpoints and :workflow_breakpoints
    log_level: :info,                            # Log level override
    log_formatter: CMDx::LogFormatters::Json.new # Log formatter override
    tags: ["payments", "critical"],              # Logging tags
    deprecated: true                             # Task deprecations
  )

  def work
    # Your logic here...
  end
end
```

> [!TIP]
> Use task-level settings for tasks that require special handling, such as payment processing,
> external API calls, or critical system operations.

### Registrations

Register middlewares, callbacks, coercions, and validators on a specific task.
Deregister options that should not be available.

```ruby
class ProcessPayment < CMDx::Task
  # Middlewares
  register :middleware, CMDx::Middlewares::Timeout
  deregister :middleware, MetricsMiddleware

  # Callbacks
  register :callback, :on_complete, proc { |task|
    duration = task.metadata[:runtime]
    StatsD.histogram("task.duration", duration, tags: ["class:#{task.class.name}"])
  }
  deregister :callback, :before_execution, :setup_request_context

  # Coercions
  register :coercion, :money, MoneyCoercion
  deregister :coercion, :point

  # Validators
  register :validator, :email, :email_validator
  deregister :validator, :phone

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
class AnalyzeData < CMDx::Task
  settings(tags: ["data", "analytics"])

  def work
    self.class.settings[:logger] #=> Global configuration value
    self.class.settings[:tags]   #=> Task configuration value => ["data", "analytics"]
  end
end
```

### Resetting

> [!WARNING]
> Resetting configuration affects the entire application. Use primarily in
> test environments or during application initialization.

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
rails generate cmdx:task ProcessOrder
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/process_order.rb
class ProcessOrder < CMDx::Task
  def work
    # Your logic here...
  end
end
```

> [!TIP]
> Use **present tense verbs + noun** for task names, eg:
> `ProcessOrder`, `SendWelcomeEmail`, `ValidatePaymentDetails`

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md
---

# Basics - Setup

Tasks are the core building blocks of CMDx, encapsulating business logic within structured, reusable objects. Each task represents a unit of work with automatic attribute validation, error handling, and execution tracking.

## Structure

Tasks inherit from `CMDx::Task` and require only a `work` method:

```ruby
class ProcessUserOrder < CMDx::Task
  def work
    # Your logic here...
  end
end
```

An exception will be raised if a work method is not defined.

```ruby
class InvalidTask < CMDx::Task
  # No `work` method defined
end

InvalidTask.execute #=> raises CMDx::UndefinedMethodError
```

## Inheritance

All configuration options are inheritable by any child classes.
Create a base class to share common configuration across tasks:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, AuthenticateUserMiddleware

  before_execution :set_correlation_id

  attribute :request_id

  private

  def set_correlation_id
    context.correlation_id ||= SecureRandom.uuid
  end
end

class ProcessOrder < ApplicationTask
  def work
    # Your logic here...
  end
end
```

## Lifecycle

Tasks follow a predictable call pattern with specific states and statuses:

| Stage | State | Status | Description |
|-------|-------|--------|-------------|
| **Instantiation** | `initialized` | `success` | Task created with context |
| **Validation** | `executing` | `success`/`failed` | Attributes validated |
| **Execution** | `executing` | `success`/`failed`/`skipped` | `work` method runs |
| **Completion** | `executed` | `success`/`failed`/`skipped` | Result finalized |
| **Freezing** | `executed` | `success`/`failed`/`skipped` | Task becomes immutable |

> [!WARNING]
> Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.

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
result = ProcessOrder.execute(order_id: 12345)

# Check execution state
result.success?         #=> true/false
result.failed?          #=> true/false
result.skipped?         #=> true/false

# Access result data
result.context.order_id #=> 12345
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

> [!WARNING]
> `execute!` behavior depends on the `task_breakpoints` or `workflow_breakpoints` configuration.
> By default, it raises exceptions only on failures.

```ruby
begin
  result = ProcessOrder.execute!(order_id: 12345)
  SendConfirmation.execute(result.context)
rescue CMDx::FailFault => e
  RetryOrderJob.perform_later(e.result.context.order_id)
rescue CMDx::SkipFault => e
  RetryOrderJob.perform_later(e.result.context.order_id)
rescue Exception => e
  BugTracker.notify(unhandled_exception: e)
end
```

## Direct Instantiation

Tasks can be instantiated directly for advanced use cases, testing, and custom execution patterns:

```ruby
# Direct instantiation
task = ProcessOrder.new(order_id: 12345, notify_customer: true)

# Access properties before execution
task.id                      #=> "abc123..." (unique task ID)
task.context.order_id        #=> 12345
task.context.notify_customer #=> true
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
result = ProcessOrder.execute(order_id: 12345)

# Execution metadata
result.id           #=> "abc123..."  (unique execution ID)
result.task         #=> ProcessOrderTask instance (frozen)
result.chain        #=> Task execution chain

# Context and metadata
result.context      #=> Context with all task data
result.metadata     #=> Hash with execution metadata
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/context.md
---

# Basics - Context

Task context provides flexible data storage, access, and sharing within task execution. It serves as the primary data container for all task inputs, intermediate results, and outputs.

## Assigning Data

Context is automatically populated with all inputs passed to a task. All keys are normalized to symbols for consistent access:

```ruby
# Direct execution
ProcessOrder.execute(user_id: 123, currency: "USD")

# Instance creation
ProcessOrder.new(user_id: 123, "currency" => "USD")
```

> [!NOTE]
> String keys are automatically converted to symbols. Use symbols for consistency in your code.

## Accessing Data

Context provides multiple access patterns with automatic nil safety:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Method style access (preferred)
    user_id = context.user_id
    amount = context.amount

    # Hash style access
    order_id = context[:order_id]
    metadata = context["metadata"]

    # Safe access with defaults
    priority = context.fetch!(:priority, "normal")
    source = context.dig(:metadata, :source)

    # Shorter alias
    total = ctx.amount * ctx.tax_rate  # ctx aliases context
  end
end
```

> [!NOTE]
> Accessing undefined context attributes returns `nil` instead of raising errors, enabling graceful handling of optional attributes.

## Modifying Context

Context supports dynamic modification during task execution:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Direct assignment
    context.user = User.find(context.user_id)
    context.order = Order.find(context.order_id)
    context.processed_at = Time.now

    # Hash-style assignment
    context[:status] = "processing"
    context["result_code"] = "SUCCESS"

    # Conditional assignment
    context.notification_sent ||= false

    # Batch updates
    context.merge!(
      status: "completed",
      total_amount: calculate_total,
      completion_time: Time.now
    )

    # Remove sensitive data
    context.delete!(:credit_card_number)
  end

  private

  def calculate_total
    context.amount + (context.amount * context.tax_rate)
  end
end
```

> [!TIP]
> Use context for automatic input attributes and intermediate results. This creates natural data flow through your task execution pipeline.

## Data Sharing

Context enables seamless data flow between related tasks in complex workflows:

```ruby
# During execution
class ProcessOrder < CMDx::Task
  def work
    # Validate order data
    validation_result = ValidateOrder.execute(context)

    # Via context
    ProcessPayment.execute(context)

    # Via result
    NotifyOrderProcessed.execute(validation_result)

    # Context now contains accumulated data from all tasks
    context.order_validated    #=> true (from validation)
    context.payment_processed  #=> true (from payment)
    context.notification_sent  #=> true (from notification)
  end
end

# After execution
result = ProcessOrder.execute(order_number: 123)

ShipOrder.execute(result)
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/basics/chain.md
---

# Basics - Chain

Chains automatically group related task executions within a thread, providing unified tracking, correlation, and execution context management. Each thread maintains its own chain through thread-local storage, eliminating the need for manual coordination.

## Management

Each thread maintains its own chain context through thread-local storage, providing automatic isolation without manual coordination.

```ruby
# Thread A
Thread.new do
  result = ProcessOrder.execute(order_id: 123)
  result.chain.id    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B (completely separate chain)
Thread.new do
  result = ProcessOrder.execute(order_id: 456)
  result.chain.id    #=> "z3a42b95-c821-7892-b156-dd7c921fe2a3"
end

# Access current thread's chain
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current thread's chain
```

> [!IMPORTANT]
> Chain operations are thread-local. Never share chain references across threads as this can lead to race conditions and data corruption.

## Links

Every task execution automatically creates or joins the current thread's chain:

```ruby
class ProcessOrder < CMDx::Task
  def work
    # First task creates new chain
    result1 = ProcessOrder.execute(order_id: 123)
    result1.chain.id           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
    result1.chain.results.size #=> 1

    # Second task joins existing chain
    result2 = SendEmail.execute(to: "user@example.com")
    result2.chain.id == result1.chain.id  #=> true
    result2.chain.results.size            #=> 2

    # Both results reference the same chain
    result1.chain.results == result2.chain.results #=> true
  end
end
```

> [!NOTE]
> Chain creation is automatic and transparent. You don't need to manually manage chain lifecycle.

## Inheritance

When tasks call subtasks within the same thread, all executions automatically inherit the current chain, creating a unified execution trail.

```ruby
class ProcessOrder < CMDx::Task
  def work
    context.order = Order.find(order_id)

    # Subtasks automatically inherit current chain
    ValidateOrder.execute
    ChargePayment.execute!(context)
    SendConfirmation.execute(order_id: order_id)
  end
end

result = ProcessOrder.execute(order_id: 123)
chain = result.chain

# All tasks share the same chain
chain.results.size #=> 4 (main task + 3 subtasks)
chain.results.map { |r| r.task.class }
#=> [ProcessOrder, ValidateOrder, ChargePayment, SendConfirmation]
```

## Structure

Chains provide comprehensive execution information with state delegation:

```ruby
result = ProcessOrder.execute(order_id: 123)
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

> [!NOTE]
> Chain state always reflects the first (outer-most) task result, not individual subtask outcomes. Subtasks maintain their own success/failure states.

---

url: https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md
---

# Interruptions - Halt

Halting stops task execution with explicit intent signaling. Tasks provide two primary halt methods that control execution flow and result in different outcomes.

## Skipping

The `skip!` method indicates a task did not meet criteria to continue execution. This represents a controlled, intentional interruption where the task determines that execution is not necessary or appropriate.

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["PHASED_OUT_TASKS"]).include?(self.class.name)

    # With a reason
    skip!("Outside business hours") unless Time.now.hour.between?(9, 17)

    order = Order.find(context.order_id)

    if order.processed?
      skip!("Order already processed")
    else
      order.process!
    end
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Executed
result.status #=> "skipped"

# Without a reason
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Outside business hours"
```

> [!NOTE]
> Skipping is not a failure or error. Skipped tasks are considered successful outcomes.

## Failing

The `fail!` method indicates a task encountered an error condition that prevents successful completion. This represents controlled failure where the task explicitly determines that execution cannot continue.

```ruby
class ProcessPayment < CMDx::Task
  def work
    # Without a reason
    skip! if Array(ENV["PHASED_OUT_TASKS"]).include?(self.class.name)

  payment = Payment.find(context.payment_id)

    # With a reason
    if payment.unsupported_type?
      fail!("Unsupported payment type")
    elsif !payment.amount.positive?
      fail!("Payment amount must be positive")
    else
      payment.charge!
    end
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Executed
result.status #=> "failed"

# Without a reason
result.reason #=> "no reason given"

# With a reason
result.reason #=> "Unsupported payment type"
```

## Metadata Enrichment

Both halt methods accept metadata to provide additional context about the interruption. Metadata is stored as a hash and becomes available through the result object.

```ruby
class ProcessSubscription < CMDx::Task
  def work
    user = User.find(context.user_id)

    if user.subscription_expired?
      # Without metadata
      skip!("Subscription expired")
    end

    unless user.payment_method_valid?
      # With metadata
      fail!(
        "Invalid payment method",
        error_code: "PAYMENT_METHOD.INVALID",
        retry_after: Time.current + 1.hour
      )
    end

    process_subscription
  end
end

result = ProcessSubscription.execute(user_id: 123)

# Without metadata
result.metadata #=> {}

# With metadata
result.metadata #=> {
                #     error_code: "PAYMENT_METHOD.INVALID",
                #     retry_after: <Time 1 hour from now>
                #   }
```

## State Transitions

Halt methods trigger specific state and status transitions:

| Method | State | Status | Outcome |
|--------|-------|--------|---------|
| `skip!` | `interrupted` | `skipped` | `good? = true`, `bad? = true` |
| `fail!` | `interrupted` | `interrupted` | `good? = false`, `bad? = true` |

```ruby
result = ProcessSubscription.execute(user_id: 123)

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
result = ProcessPayment.execute(payment_id: 123)

case result.status
when "success"
  puts "Payment processed: $#{result.context.payment.amount}"
when "skipped"
  puts "Payment skipped: #{result.reason}"
when "failed"
  puts "Payment failed: #{result.reason}"
  handle_payment_error(result.metadata[:code])
end
```

### Bang execution

Raises exceptions for halt conditions based on `task_breakpoints` configuration:

```ruby
begin
  result = ProcessPayment.execute!(payment_id: 123)
  puts "Success: Payment processed"
rescue CMDx::SkipFault => e
  puts "Skipped: #{e.message}"
rescue CMDx::FailFault => e
  puts "Failed: #{e.message}"
  handle_payment_failure(e.result.metadata[:code])
end
```

## Best Practices

Always try to provide a `reason` when using halt methods. This provides clear context for debugging and creates meaningful exception messages.

```ruby
# Good: Clear, specific reason
skip!("User account suspended until manual review")
fail!("Credit card declined by issuer", code: "CARD_DECLINED")

# Acceptable: Generic, non-specific reason
skip!("Suspended")
fail!("Declined")

# Bad: Default, cannot determine reason
skip! #=> "no reason given"
fail! #=> "no reason given"
```

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

> [!NOTE]
> All fault exceptions inherit from `CMDx::Fault` and provide access to the complete task execution context including result, task, context, and chain information.

## Fault Handling

```ruby
begin
  ProcessOrder.execute!(order_id: 123)
rescue CMDx::SkipFault => e
  logger.info "Order processing skipped: #{e.message}"
  schedule_retry(e.context.order_id)
rescue CMDx::FailFault => e
  logger.error "Order processing failed: #{e.message}"
  notify_customer(e.context.customer_email, e.result.metadata[:code])
rescue CMDx::Fault => e
  logger.warn "Order processing interrupted: #{e.message}"
  rollback_transaction
end
```

## Data Access

Faults provide comprehensive access to execution context, eg:

```ruby
begin
  UserRegistration.execute!(email: email, password: password)
rescue CMDx::Fault => e
  # Result information
  e.result.state     #=> "interrupted"
  e.result.status    #=> "failed" or "skipped"
  e.result.reason    #=> "Email already exists"

  # Task information
  e.task.class       #=> <UserRegistration>
  e.task.id          #=> "abc123..."

  # Context data
  e.context.email    #=> "user@example.com"
  e.context.password #=> "[FILTERED]"

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
  PaymentWorkflow.execute!(payment_data: data)
rescue CMDx::FailFault.for?(CardValidator, PaymentProcessor) => e
  # Handle only payment-related failures
  retry_with_backup_method(e.context)
rescue CMDx::SkipFault.for?(FraudCheck, RiskAssessment) => e
  # Handle security-related skips
  task_for_manual_review(e.context.transaction_id)
end
```

### Custom Logic Matching

```ruby
begin
  OrderProcessor.execute!(order: order_data)
rescue CMDx::Fault.matches? { |f| f.context.order_value > 1000 } => e
  escalate_high_value_failure(e)
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:retry_count] > 3 } => e
  abandon_processing(e)
rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_type] == "timeout" } => e
  increase_timeout_and_retry(e)
end
```

## Fault Propagation

Use `throw!` to propagate failures while preserving fault context and maintaining the error chain for debugging.

### Basic Propagation

```ruby
class OrderProcessor < CMDx::Task
  def work
    # Validate order
    validation_result = OrderValidator.execute(context)
    throw!(validation_result) # Skipped or Failed

    # Check inventory
    check_inventory = CheckInventory.execute(context)
    throw!(check_inventory) if check_inventory.skipped?

    # Process payment
    payment_result = PaymentProcessor.execute(context)
    throw!(payment_result) if payment_result.failed?

    # Continue processing
    complete_order
  end
end
```

### Additional Metadata

```ruby
class WorkflowProcessor < CMDx::Task
  def work
    step_result = DataValidation.execute(context)

    if step_result.failed?
      throw!(step_result, {
        workflow_stage: "validation",
        can_retry: true,
        next_step: "data_cleanup"
      })
    end

    continue_workflow
  end
end
```

## Chain Analysis

Results provide methods to analyze fault propagation and identify original failure sources in complex execution chains.

```ruby
result = PaymentWorkflow.execute(invalid_data)

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

### Non-bang execution

The `execute` method captures **all** unhandled exceptions and converts them to failed results, ensuring predictable behavior and consistent result processing.

```ruby
class ProcessPayment < CMDx::Task
  def work
    raise UnknownPaymentMethod, "unsupported payment method"
  end
end

result = ProcessPayment.execute
result.state    #=> "interrupted"
result.status   #=> "success"
result.failed?  #=> true
result.reason   #=> "[UnknownPaymentMethod] unsupported payment method"
result.cause    #=> <UnknownPaymentMethod>
```

### Bang execution

The `execute!` method allows unhandled exceptions to propagate, enabling standard Ruby exception handling while respecting CMDx fault configuration.

```ruby
class ProcessPayment < CMDx::Task
  def work
    raise UnknownPaymentMethod, "unsupported payment method"
  end
end

begin
  ProcessPayment.execute!
rescue UnknownPaymentMethod => e
  puts "Handle exception: #{e.message}"
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md
---

# Outcomes - Result

The result object is the comprehensive return value of task execution, providing complete information about the execution outcome, state, timing, and any data produced during the task lifecycle. Results serve as the primary interface for inspecting task execution outcomes and chaining task operations.

## Result Attributes

> [!NOTE]
> Result objects are immutable after task execution completes and reflect the final state.

Every result provides access to essential execution information:

```ruby
result = ProcessOrder.execute(order_id: 123)

# Object data
result.task     #=> <ProcessOrder>
result.context  #=> <CMDx::Context>
result.chain    #=> <CMDx::Chain>

# Execution data
result.state    #=> "interrupted"
result.status   #=> "failed"

# Fault data
result.reason   #=> "Unsupported payment type"
result.cause    #=> <CMDx::FailFault>
result.metadata #=> { error_code: "PAYMENT_TYPE.UNSUPPORTED" }
```

## Lifecycle Information

Results provide comprehensive methods for checking execution state and status:

```ruby
result = ProcessOrder.execute(order_id: 123)

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
result = ProcessOrder.execute(order_id: 123)

result.outcome #=> "success" (state and status)
```

## Chain Analysis

Use these methods to trace the root cause of faults or trace the cause points.

```ruby
result = ProcessOrderWorkflow.execute(order_id: 123)

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
result = ProcessOrder.execute(order_id: 123)

# Position in execution sequence
result.index #=> 0 (first task in chain)

# Access via chain
result.chain.results[result.index] == result #=> true
```

## Handlers

Use result handlers for clean, functional-style conditional logic. Handlers return the result object, enabling method chaining and fluent interfaces.

```ruby
result = ProcessOrder.execute(order_id: 123)

# Status-based handlers
result
  .on_success { |result| send_confirmation_email(result) }
  .on_failed { |result| handle_payment_failure(result) }
  .on_skipped { |result| log_skip_reason(result) }

# State-based handlers
result
  .on_complete { |result| update_order_status(result) }
  .on_interrupted { |result| cleanup_partial_state(result) }

# Outcome-based handlers
result
  .on_good { |result| increment_success_counter(result) }
  .on_bad { |result| alert_operations_team(result) }
```

## Pattern Matching

> [!NOTE]
> Pattern matching requires Ruby 3.0+. The `deconstruct` method returns a `[state, status]` array pattern, while `deconstruct_keys` provides hash access to result attributes.

Results support Ruby's pattern matching through array and hash deconstruction:

### Array Pattern

```ruby
result = ProcessOrder.execute(order_id: 123)

case result
in ["complete", "success"]
  redirect_to success_page
in ["interrupted", "failed"]
  retry_with_backoff(result)
in ["interrupted", "skipped"]
  log_skip_and_continue
end
```

### Hash Pattern

```ruby
result = ProcessOrder.execute(order_id: 123)

case result
in { state: "complete", status: "success" }
  celebrate_success
in { status: "failed", metadata: { retryable: true } }
  schedule_retry(result)
in { bad: true, metadata: { reason: String => reason } }
  escalate_error("Failed: #{reason}")
end
```

### Pattern Guards

```ruby
case result
in { status: "failed", metadata: { attempts: n } } if n < 3
  retry_task_with_delay(result, n * 2)
in { status: "failed", metadata: { attempts: n } } if n >= 3
  mark_permanently_failed(result)
in { runtime: time } if time > performance_threshold
  investigate_performance_issue(result)
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

> [!IMPORTANT]
> States are automatically managed during task execution and should **never** be modified manually. State transitions are handled internally by the CMDx framework.

```ruby
# Valid state transition flow
initialized → executing → complete    (successful execution)
initialized → executing → interrupted (skipped/failed execution)
```

## Predicates

Use state predicates to check the current execution lifecycle:

```ruby
result = OrderFulfillment.execute

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
result = ProcessOrder.execute

# Individual state handlers
result
  .on_complete { |result| send_confirmation_email(result) }
  .on_interrupted { |result| schedule_retry(result) }
  .on_executed { |result| update_analytics(result) }
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
result = PaymentProcessing.execute

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
result = OrderFulfillment.execute

# Individual status handlers
result
  .on_success { |result| schedule_delivery(result) }
  .on_skipped { |result| notify_backorder(result) }
  .on_failed { |result| refund_payment(result) }

# Outcome-based handlers
result
  .on_good { |result| update_inventory(result) }
  .on_bad { |result| log_negative_outcome(result) }
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
class CreateUser < CMDx::Task
  attribute :email
  attributes :age, :ssn

  # Alias for attributes (preferred)
  optional :phone
  optional :sex, :tags

  def work
    email #=> "user@example.com"
    age   #=> 25
    ssn   #=> nil
    phone #=> nil
    sex   #=> nil
    tags  #=> ["premium", "beta"]
  end
end

# Attributes passed as keyword arguments
CreateUser.execute(
  email: "user@example.com",
  age: 25,
  tags: ["premium", "beta"]
)
```

### Required

Required attributes must be provided in call arguments or task execution will fail.

```ruby
class CreateUser < CMDx::Task
  attribute :email, required: true
  attributes :age, :ssn, required: true

  # Alias for attributes => required: true (preferred)
  required :phone
  required :sex, :tags

  def work
    email #=> "user@example.com"
    age   #=> 25
    ssn   #=> "123-456"
    phone #=> "888-9909"
    sex   #=> :male
    tags  #=> ["premium", "beta"]
  end
end

# Attributes passed as keyword arguments
CreateUser.execute(
  email: "user@example.com",
  age: 25,
  ssn: "123-456",
  phone: "888-9909",
  sex: :male,
  tags: ["premium", "beta"]
)
```

## Sources

Attributes delegate to accessible objects within the task. The default source is `:context`, but any accessible method or object can serve as an attribute source.

### Context

```ruby
class UpdateProfile < CMDx::Task
  # Default source is :context
  required :user_id
  optional :avatar_url

  # Explicitly specify context source
  attribute :email, source: :context

  def work
    user_id    #=> context.user_id
    email      #=> context.email
    avatar_url #=> context.avatar_url
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic source values:

```ruby
class UpdateProfile < CMDx::Task
  attributes :email, :settings, source: :user

  # Access from declared attributes
  attribute :email_token, source: :settings

  def work
    # Your logic here...
  end

  private

  method
    @user ||= User.find(1)
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic source values:

```ruby
class UpdateProfile < CMDx::Task
  # Proc
  attribute :email, source: proc { Current.user }

  # Lambda
  attribute :email, source: -> { Current.user }
end
```

### Class or Module

For complex source logic, use classes or modules:

```ruby
class UserSourcer
  def self.call(task)
    User.find(task.context.user_id)
  end
end

class UpdateProfile < CMDx::Task
  # Class or Module
  attribute :email, source: UserSourcer

  # Instance
  attribute :email, source: UserSourcer.new
end
```

## Nesting

Nested attributes enable complex attribute structures where child attributes automatically inherit their parent as the source. This allows validation and access of structured data.

> [!IMPORTANT]
> All options available to top-level attributes are available to nested attributes, eg: naming, coercions, and validations

```ruby
class CreateShipment < CMDx::Task
  # Required parent with required children
  required :shipping_address do
    required :street, :city, :state, :zip
    optional :apartment
    attribute :instructions
  end

  # Optional parent with conditional children
  optional :billing_address do
    required :street, :city # Only required if billing_address provided
    optional :same_as_shipping, prefix: true
  end

  # Multi-level nesting
  attribute :special_handling do
    required :type

    optional :insurance do
      required :coverage_amount
      optional :carrier
    end
  end

  def work
    shipping_address #=> { street: "123 Main St" ... }
    street           #=> "123 Main St"
    apartment        #=> nil
  end
end

CreateShipment.execute(
  order_id: 123,
  shipping_address: {
    street: "123 Main St",
    city: "Miami",
    state: "FL",
    zip: "33101",
    instructions: "Leave at door"
  },
  special_handling: {
    type: "fragile",
    insurance: {
      coverage_amount: 500.00,
      carrier: "FedEx"
    }
  }
)
```

> [!TIP]
> Child attributes are only required when their parent attribute is provided, enabling flexible optional structures.

## Error Handling

Attribute validation failures result in structured error information with details about each failed attribute.

> [!IMPORTANT]
> Nested attributes are only ever evaluated when the parent attribute is available and valid.

```ruby
class ProcessOrder < CMDx::Task
  required :user_id, :order_id
  required :shipping_address do
    required :street, :city
  end

  def work
    # Your logic here...
  end
end

# Missing required top-level attributes
result = ProcessOrder.execute(user_id: 123)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "order_id is required. shipping_address is required."
result.metadata #=> {
                #     messages: {
                #       order_id: ["is required"],
                #       order_id: ["is required"]
                #     }
                #   }

# Missing required nested attributes
result = ProcessOrder.execute(
  user_id: 123,
  order_id: 456,
  shipping_address: { street: "123 Main St" } # Missing city
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "city is required."
result.metadata #=> {
                #     messages: {
                #       city: ["is required"]
                #     }
                #   }
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/naming.md
---

# Attributes - Naming

Attribute naming provides method name customization to prevent conflicts and enable flexible attribute access patterns. When attributes share names with existing methods or when multiple attributes from different sources have the same name, affixing ensures clean method resolution within tasks.

> [!IMPORTANT]
> Affixing modifies only the generated accessor method names within tasks.

## Prefix

Adds a prefix to the generated accessor method name.

```ruby
class UpdateCustomer < CMDx::Task
  # Dynamic from attribute source
  attribute :id, prefix: true

  # Static
  attribute :name, prefix: "customer_"

  def work
    context_id    #=> 123
    customer_name #=> "Jane Smith"
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(id: 123, name: "Jane Smith")
```

## Suffix

Adds a suffix to the generated accessor method name.

```ruby
class UpdateCustomer < CMDx::Task
  # Dynamic from attribute source
  attribute :email, suffix: true

  # Static
  attribute :phone, suffix: "_number"

  def work
    email_context #=> "jane@example.com"
    phone_number  #=> "555-0123"
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(email: "jane@example.com", phone: "555-0123")
```

## As

Completely renames the generated accessor method.

```ruby
class UpdateCustomer < CMDx::Task
  attribute :birthday, as: :bday

  def work
    bday #=> <Date>
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(birthday: Date.new(2020, 10, 31))
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/coercions.md
---

# Attributes - Coercions

Attribute coercions automatically convert task arguments to expected types, ensuring type safety while providing flexible input handling. Coercions transform raw input values into the specified types, supporting simple conversions like string-to-integer and complex operations like JSON parsing.

## Usage

Define attribute types to enable automatic coercion:

```ruby
class ProcessPayment < CMDx::Task
  # Coerce into a date
  attribute :paid_with, type: :symbol

  # Coerce into a float fallback to big decimal
  attribute :total, type: [:float, :big_decimal]

  # Coerce with options
  attribute :paid_on, type: :date, strptime: "%m-%d-%Y"

  def work
    paid_with #=> :amex
    paid_on   #=> <Date 2024-01-23>
    total     #=> 34.99 (Float)
  end
end

ProcessPayment.execute(
  paid_with: "amex",
  paid_on: "01-23-2020",
  total: "34.99"
)
```

> [!TIP]
> Specify multiple types for fallback coercion. CMDx attempts each type in order until one succeeds.

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
| `:string` | | String conversion | `123` → `123` |
| `:symbol` | | Symbol conversion | `"abc"` → `:abc` |
| `:time` | `:strptime` | Time objects | `"10:30:00"` → `Time.new(2024, 1, 23, 10, 30)` |

## Declarations

> [!IMPORTANT]
> Coercions must raise a CMDx::CoercionError and its message is used as part of the fault reason and metadata.

### Proc or Lambda

Use anonymous functions for simple coercion logic:

```ruby
class FindLocation < CMDx::Task
  # Proc
  register :callback, :point, proc do |value, options = {}|
    begin
      Point(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a point"
    end
  end

  # Lambda
  register :callback, :point, ->(value, options = {}) {
    begin
      Point(value)
    rescue StandardError
      raise CMDx::CoercionError, "could not convert into a point"
    end
  }
end
```

### Class or Module

Register custom coercion logic for specialized type handling:

```ruby
class PointCoercion
  def self.call(value, options = {})
    Point(value)
  rescue StandardError
    raise CMDx::CoercionError, "could not convert into a point"
  end
end

class FindLocation < CMDx::Task
  attribute :longitude, type: :point

  register :coercion, :point, PointCoercion
end
```

## Removals

Remove custom coercions when no longer needed:

```ruby
class ProcessOrder < CMDx::Task
  deregister :coercion, :point
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Error Handling

Coercion failures provide detailed error information including attribute paths, attempted types, and specific failure reasons:

```ruby
class ProcessData < CMDx::Task
  attribute  :count, type: :integer
  attribute  :amount, type: [:float, :big_decimal]

  def work
    # Your logic here...
  end
end

result = ProcessData.execute(
  count: "not-a-number",
  amount: "invalid-float"
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "count could not coerce into an integer. amount could not coerce into one of: float, big_decimal."
result.metadata #=> {
                #     messages: {
                #       count: ["could not coerce into an integer"],
                #       amount: ["could not coerce into one of: float, big_decimal"]
                #     }
                #   }
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/attributes/validations.md
---

# Attributes - Validations

Attribute validations ensure task arguments meet specified requirements before execution begins. Validations run after coercions and provide declarative rules for data integrity, supporting both built-in validators and custom validation logic.

## Usage

Define validation rules on attributes to enforce data requirements:

```ruby
class ProcessOrder < CMDx::Task
  # Required field with presence validation
  attribute :customer_id, presence: true

  # String with length constraints
  attribute :notes, length: { minimum: 10, maximum: 500 }

  # Numeric range validation
  attribute :quantity, inclusion: { in: 1..100 }

  # Format validation for email
  attribute :email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    customer_id #=> "12345"
    notes       #=> "Please deliver to front door"
    quantity    #=> 5
    email       #=> "customer@example.com"
  end
end

ProcessOrder.execute(
  customer_id: "12345",
  notes: "Please deliver to front door",
  quantity: 5,
  email: "customer@example.com"
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
class ProcessOrder < CMDx::Task
  attribute :status, exclusion: { in: %w[out_of_stock discontinued] }

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
class ProcessOrder < CMDx::Task
  attribute :email, exclusion: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  attribute :email, exclusion: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }

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
class ProcessOrder < CMDx::Task
  attribute :status, inclusion: { in: %w[preorder in_stock] }

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
class CreateUser < CMDx::Task
  attribute :username, length: { within: 1..30 }

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
class CreateUser < CMDx::Task
  attribute :age, length: { min: 13 }

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
class CreateUser < CMDx::Task
  attribute :accept_tos, presence: true

  attribute :accept_tos, presence: { message: "needs to be accepted" }

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
> Custom validators must raise a CMDx::ValidationError and its message is used as part of the fault reason and metadata.

### Proc or Lambda

Use anonymous functions for simple validation logic:

```ruby
class CreateWebsite < CMDx::Task
  # Proc
  register :validator, :domain, proc do |value, options = {}|
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  end

  # Lambda
  register :validator, :domain, ->(value, options = {}) {
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  }
end
```

### Class or Module

Register custom validation logic for specialized requirements:

```ruby
class DomainValidator
  def self.call(value, options = {})
    unless value.match?(/\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/)
      raise CMDx::ValidationError, "invalid domain format"
    end
  end
end

class CreateWebsite < CMDx::Task
  register :validator, :domain, DomainValidator

  attribute :domain_name, domain: true
end
```

## Removals

Remove custom validators when no longer needed:

```ruby
class CreateWebsite < CMDx::Task
  deregister :validator, :domain
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Error Handling

Validation failures provide detailed error information including attribute paths, validation rules, and specific failure reasons:

```ruby
class CreateUser < CMDx::Task
  attribute :username, presence: true, length: { minimum: 3, maximum: 20 }
  attribute :age, numeric: { greater_than: 13, less_than: 120 }
  attribute :role, inclusion: { in: [:user, :moderator, :admin] }
  attribute :email, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def work
    # Your logic here...
  end
end

result = CreateUser.execute(
  username: "ab",           # Too short
  age: 10,                  # Too young
  role: :superuser,         # Not in allowed list
  email: "invalid-email"    # Invalid format
)

result.state    #=> "interrupted"
result.status   #=> "failed"
result.reason   #=> "username is too short (minimum is 3 characters). age must be greater than 13. role is not included in the list. email is invalid."
result.metadata #=> {
                #     messages: {
                #       username: ["is too short (minimum is 3 characters)"],
                #       age: ["must be greater than 13"],
                #       role: ["is not included in the list"],
                #       email: ["is invalid"]
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
class ProcessOrder < CMDx::Task
  attribute :charge_type, default: :credit_card
  attribute :priority, default: "standard"
  attribute :send_email, default: true
  attribute :max_retries, default: 3
  attribute :tags, default: []
  attribute :data, default: {}

  def work
    charge_type #=> :credit_card
    priority    #=> "standard"
    send_email  #=> true
    max_retries #=> 3
    tags        #=> []
    data        #=> {}
  end
end
```

### Symbol References

Reference instance methods by symbol for dynamic default values:

```ruby
class ProcessOrder < CMDx::Task
  attribute :priority, default: :default_priority

  def work
    # Your logic here...
  end

  private

  def default_priority
    Current.account.pro? ? "priority" : "standard"
  end
end
```

### Proc or Lambda

Use anonymous functions for dynamic default values:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  attribute :send_email, default: proc { Current.account.email_api_key? }

  # Lambda
  attribute :priority, default: -> { Current.account.pro? ? "priority" : "standard" }
end
```

## Coercions and Validations

Defaults are subject to the same coercion and validation rules as provided values, ensuring consistency and catching configuration errors early.

```ruby
class ConfigureService < CMDx::Task
  # Coercions
  attribute :retry_count, default: "3", type: :integer

  # Validations
  optional :priority, default: "medium", inclusion: { in: %w[low medium high urgent] }
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/callbacks.md
---

# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

> **Note:** Callbacks execute in the order they are declared within each hook type. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

## Available Callbacks

Callbacks execute in precise lifecycle order. Here is the complete execution sequence:

```ruby
1. before_validation           # Pre-validation setup
2. before_execution            # Setup and preparation
# Task work executed
3. on_[complete|interrupted]   # Based on execution state
4. on_executed                 # Task finished (any outcome)
5. on_[success|skipped|failed] # Based on execution status
6. on_[good|bad]               # Based on outcome classification
```

## Declarations

### Symbol References

Reference instance methods by symbol for simple callback logic:

```ruby
class ProcessOrder < CMDx::Task
  before_execution :find_order

  # Batch declarations (works for any type)
  on_complete :notify_customer, :update_inventory

  def work
    # Your logic here...
  end

  private

  def find_order
    @order ||= Order.find(context.order_id)
  end

  def notify_customer
    CustomerNotifier.call(context.user, result)
  end

  def update_inventory
    InventoryService.update(context.product_ids, result)
  end
end
```

### Proc or Lambda

Use anonymous functions for inline callback logic:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  on_interrupted proc { |task| BuildLine.stop! }

  # Lambda
  on_complete -> { BuildLine.resume! }
end
```

### Class or Module

Implement reusable callback logic in dedicated classes:

```ruby
class SendNotificationCallback
  def call(task)
    if task.result.success?
      EmailApi.deliver_success_email(task.context.user)
    else
      EmailApi.deliver_issue_email(task.context.admin)
    end
  end
end

class ProcessOrder < CMDx::Task
  # Class or Module
  on_success SendNotificationCallback

  # Instance
  on_interrupted SendNotificationCallback.new
end
```

### Conditional Execution

Control callback execution with conditional logic:

```ruby
class AbilityCheck
  def call(task)
    task.context.user.can?(:send_email)
  end
end

class ProcessOrder < CMDx::Task
  # If and/or Unless
  before_execution :notify_customer, if: :email_available?, unless: :email_temporary?

  # Proc
  on_failure :increment_failure, if: ->(task) { Rails.env.production? && task.class.name.include?("Legacy") }

  # Lambda
  on_success :ping_warehouse, if: proc { |task| task.context.products_on_backorder? }

  # Class or Module
  on_complete :send_notification, unless: AbilityCheck

  # Instance
  on_complete :send_notification, if: AbilityCheck.new

  def work
    # Your logic here...
  end

  private

  def email_available?
    context.user.email.present?
  end

  def email_temporary?
    context.user.email_service == :temporary
  end
end
```

## Callback Removal

Remove callbacks at runtime for dynamic behavior control:

```ruby
class ProcessOrder < CMDx::Task
  # Symbol
  deregister :callback, :before_execution, :notify_customer

  # Class or Module (no instances)
  deregister :callback, :on_complete, SendNotificationCallback
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

---

url: https://github.com/drexed/cmdx/blob/main/docs/middlewares.md
---

# Middlewares

Middleware provides Rack-style wrappers around task execution for cross-cutting concerns like authentication, logging, caching, and error handling.

## Order

Middleware executes in a nested fashion, creating an onion-like execution pattern:

> [!IMPORTANT]
> Middleware executes in the order they are registered, with the first registered middleware being the outermost wrapper.

```ruby
class ProcessOrder < CMDx::Task
  register :middleware, TimingMiddleware         # 1st: outermost wrapper
  register :middleware, AuthenticationMiddleware # 2nd: middle wrapper
  register :middleware, ValidationMiddleware     # 3rd: innermost wrapper

  def work
    # Your logic here...
  end
end

# Execution flow:
# 1. TimingMiddleware (before)
# 2.   AuthenticationMiddleware (before)
# 3.     ValidationMiddleware (before)
# 4.       [task execution]
# 5.     ValidationMiddleware (after)
# 6.   AuthenticationMiddleware (after)
# 7. TimingMiddleware (after)
```

## Declarations

### Proc or Lambda

Use anonymous functions for simple middleware logic:

```ruby
class ProcessOrder < CMDx::Task
  # Proc
  register :middleware, proc do |task, options, &block|
    result = block.call
    APM.increment(result.status)
    result
  end

  # Lambda
  register :middleware, ->(task, options, &block) {
    result = block.call
    APM.increment(result.status)
    result
  }
end
```

### Class or Module

For complex middleware logic, use classes or modules:

```ruby
class MetricsMiddleware
  def call(task, options)
    result = yield
    APM.increment(result.status)
  ensure
    result # Always return result
  end
end

class ProcessOrder < CMDx::Task
  # Class or Module
  register :middleware, MetricsMiddleware

  # Instance
  register :middleware, MetricsMiddleware.new

  # With options
  register :middleware, AnalyticsMiddleware, api_key: ENV["ANALYTICS_API_KEY"]
  register :middleware, AnalyticsMiddleware.new(ENV["ANALYTICS_API_KEY"])
end
```

## Removals

Class and Module based declarations can be removed at a global and task level.

```ruby
class ProcessOrder < CMDx::Task
  # Class or Module (no instances)
  deregister :middleware, MetricsMiddleware
end
```

> [!IMPORTANT]
> Only one removal operation is allowed per `deregister` call. Multiple removals require separate calls.

## Built-in

### Timeout

Ensures task execution doesn't exceed a specified time limit:

```ruby
class ProcessOrder < CMDx::Task
  # Default timeout: 3 seconds
  register :middleware, CMDx::Middlewares::Timeout

  # Seconds (takes Numeric, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, seconds: :max_execution_time

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Timeout, unless: -> { self.class.name.include?("Fast") }

  def work
    # Your logic here...
  end

  private

  def max_execution_time
    Rails.env.production? ? 1 : 5
  end
end

# Slow task
result = ProcessOrder.execute

result.state    #=> "interrupted"
result.status   #=> "failure"
result.reason   #=> "[CMDx::TimeoutError] execution exceeded 3 seconds"
result.cause    #=> <CMDx::TimeoutError>
result.metadata #=> { limit: 3 }
```

### Correlate

Tags tasks with a global correlation ID for distributed tracing:

```ruby
class ProcessOrder < CMDx::Task
  # Default correlation ID generation
  register :middleware, CMDx::Middlewares::Correlate

  # Seconds (takes Object, Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, id: proc { |task| task.context.request_id }

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Correlate, if: :tracing_enabled?

  def work
    # Your logic here...
  end

  private

  def tracing_enabled?
    ENV["TRACING_ENABLED"] == "true"
  end
end

result = ProcessOrder.execute
result.metadata #=> { correlation_id: "550e8400-e29b-41d4-a716-446655440000" }
```

### Runtime

The runtime middleware tags tasks with how long it took to execute the task.
The calculation uses a monotonic clock and the time is returned in milliseconds.

```ruby
class SlowTaskCheck
  def call(task)
    task.context.account.debuggable?
  end
end

class ProcessOrder < CMDx::Task
  # Default timeout is 3 seconds
  register :middleware, CMDx::Middlewares::Runtime

  # If or Unless (takes Symbol, Proc, Lambda, Class, Module)
  register :middleware, CMDx::Middlewares::Runtime, if: SlowTaskCheck
end

result = ProcessOrder.execute
result.metadata #=> { runtime: 543 } (ms)
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

```text
# Success (INFO level)
I, [2022-07-17T18:43:15.000000 #3784] INFO -- CreateOrder:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task"
class="CreateOrder" state="complete" status="success" metadata={runtime: 123}

# Skipped (WARN level)
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidatePayment:
index=1 state="interrupted" status="skipped" reason="Order already processed"

# Failed (ERROR level)
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessPayment:
index=2 state="interrupted" status="failed" metadata={error_code: "INSUFFICIENT_FUNDS"}

# Failed Chain
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- OrderWorkflow:
caused_failure={index: 2, class: "ProcessPayment", status: "failed"}
threw_failure={index: 1, class: "ValidatePayment", status: "failed"}
```

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
| `class` | Task class name | `ProcessOrderTask` |
| `id` | Unique task instance ID | `018c2b95-b764-7615...` |
| `tags` | Custom categorization | `["priority", "payment"]` |

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
class ProcessOrder < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Order processed")
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
class ProcessOrder < CMDx::Task
  attribute :amount, type: :float

  def work
    # Your logic here...
  end
end

I18n.with_locale(:fr) do
  result = ProcessOrder.execute(amount: "invalid")
  result.metadata[:messages][:amount] #=> ["impossible de contraindre en float"]
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

```ruby
class ProcessLegacyPayment < CMDx::Task
  settings(deprecated: :raise)

  def work
    # Will never execute...
  end
end

result = ProcessLegacyPayment.execute
#=> raises CMDx::DeprecationError: "ProcessLegacyPayment usage prohibited"
```

> [!WARNING]
> Use `:raise` mode carefully in production environments as it will break existing workflows immediately.

### Log

`:log` mode allows continued usage while tracking deprecation warnings. Perfect for gradual migration scenarios where immediate replacement isn't feasible.

```ruby
class ProcessOldPayment < CMDx::Task
  attribute :amount, type: :float

  # Same
  settings(deprecated: true)

  def work
    # Executes but logs deprecation warning...
  end
end

result = ProcessOldPayment.execute
result.successful? #=> true

# Deprecation warning appears in logs:
# WARN -- : DEPRECATED: ProcessOldPayment - migrate to replacement or discontinue use
```

### Warn

`:warn` mode issues Ruby warnings visible in development and testing environments. Useful for alerting developers without affecting production logging.

```ruby
class ProcessObsoletePayment < CMDx::Task
  settings(deprecated: :warn)

  def work
    # Executes but emits Ruby warning...
  end
end

result = ProcessObsoletePayment.execute
result.successful? #=> true

# Ruby warning appears in stderr:
# [ProcessObsoletePayment] DEPRECATED: migrate to replacement or discontinue use
```

## Declarations

### Symbol or String

```ruby
class LegacyIntegration < CMDx::Task
  # Symbol
  settings(deprecated: :raise)

  # String
  settings(deprecated: "warn")
end
```

### Boolean or Nil

```ruby
class LegacyIntegration < CMDx::Task
  # Deprecates with default :log mode
  settings(deprecated: true)

  # Skips deprecation
  settings(deprecated: false)
  settings(deprecated: nil)
end
```

### Method

```ruby
class LegacyIntegration < CMDx::Task
  # Symbol
  settings(deprecated: :deprecated?)

  def work
    # Your logic here...
  end

  private

  def deprecated?
    Time.now.year > 2020 ? :raise : false
  end
end
```

### Proc or Lambda

```ruby
class LegacyIntegration < CMDx::Task
  # Proc
  settings(deprecated: proc { Rails.env.local? ? :raise : :log })

  # Lambda
  settings(deprecated: -> { Current.user.legacy? ? :warn : :raise })
end
```

### Class or Module

```ruby
class LegacyTaskDeprecator
  def call(task)
    task.class.name.include?("Legacy")
  end
end

class LegacyIntegration < CMDx::Task
  # Class or Module
  settings(deprecated: LegacyTaskDeprecator)

  # Instance
  settings(deprecated: LegacyTaskDeprecator.new)
end
```

---

url: https://github.com/drexed/cmdx/blob/main/docs/workflows.md
---

# Workflows

CMDx::Workflow orchestrates sequential execution of multiple tasks in a linear pipeline. Workflows provide a declarative DSL for composing complex business logic from individual task components, with support for conditional execution, context propagation, and configurable halt behavior.

## Declarations

Tasks execute in declaration order (FIFO). The workflow context propagates to each task, allowing access to data from previous executions.

> [!WARNING]
> Do **NOT** define a `work` method in workflow tasks.
> The included module automatically provides the execution logic.

### Task

```ruby
class NotificationWorkflow < CMDx::Task
  include CMDx::Workflow

  task SendNotificationCheck
  task PrepNotificationTemplate

  tasks SendEmail, SendSms, SendPush
end
```

### Group

Group related tasks for better organization and shared configuration:

```ruby
class DataProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  # Validation phase
  tasks ValidateInput, ValidateSchema, ValidateBusinessRules, breakpoints: ["skipped"]

  # Processing phase
  tasks TransformData, ApplyRules, CalculateMetrics

  # Output phase
  tasks GenerateReport, SaveResults, NotifyStakeholders
end
```

> [!IMPORTANT]
> Settings and conditionals for a group apply to all tasks within that group.

### Conditionals

Conditionals support multiple syntaxes for flexible execution control:

```ruby
class DeliveryCheck
  def call(task)
    task.context.user.can?(:send_email)
  end
end

class NotificationWorkflow < CMDx::Task
  include CMDx::Workflow

  # If and/or Unless
  task SendEmail, if: :email_available?, unless: :email_temporary?

  # Proc
  task SendEmail, if: ->(workflow) { Rails.env.production? && workflow.class.name.include?("Zip") }

  # Lambda
  task SendEmail, if: proc { |workflow| workflow.context.products_on_backorder? }

  # Class or Module
  task SendEmail, unless: AbilityCheck

  # Instance
  task SendEmail, if: AbilityCheck.new

  # Conditional applies to all tasks of this declaration group
  tasks SendEmail, SendSms, SendPush, if: :email_available?

  private

  def email_available?
    context.user.email.present?
  end

  def email_temporary?
    context.user.email_service == :temporary
  end
end
```

## Halt Behavior

By default skipped tasks are considered no-op executions and does not stop workflow execution.
This is configurable via global and task level breakpoint settings. Task and group configurations
can be used together within a workflow.

```ruby
class DataWorkflow < CMDx::Task
  include CMDx::Workflow

  task LoadDataTask      # If fails → workflow stops
  task ValidateDataTask  # If skipped → workflow continues
  task SaveDataTask      # Only runs if no failures occurred
end
```

### Task Configuration

Configure halt behavior for the entire workflow:

```ruby
class CriticalWorkflow < CMDx::Task
  include CMDx::Workflow

  # Halt on both failed and skipped results
  settings(workflow_breakpoints: ["skipped", "failed"])

  task LoadCriticalDataTask
  task ValidateCriticalDataTask
end

class OptionalWorkflow < CMDx::Task
  include CMDx::Workflow

  # Never halt, always continue
  settings(breakpoints: [])

  task TryLoadDataTask
  task TryValidateDataTask
  task TrySaveDataTask
end
```

### Group Configuration

Different task groups can have different halt behavior:

```ruby
class AccountWorkflow < CMDx::Task
  include CMDx::Workflow

  task CreateUser, ValidateUser, workflow_breakpoints: ["skipped", "failed"]

  # Never halt, always continue
  task SendWelcomeEmail, CreateProfile, breakpoints: []
end
```

## Nested Workflows

Workflows can task other workflows for hierarchical composition:

```ruby
class DataPreProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  task ValidateInputTask
  task SanitizeDataTask
end

class DataProcessingWorkflow < CMDx::Task
  include CMDx::Workflow

  tasks TransformDataTask, ApplyBusinessLogicTask
end

class CompleteDataWorkflow < CMDx::Task
  include CMDx::Workflow

  task DataPreProcessingWorkflow
  task DataProcessingWorkflow, if: proc { context.pre_processing_successful? }
  task GenerateReportTask
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

```txt
/app
  /tasks
    /orders
      - charge_order.rb
      - validate_order.rb
      - fulfill_order.rb
      - process_order.rb # workflow
    /notifications
      - send_email.rb
      - send_sms.rb
      - post_slack_message.rb
      - deliver_notifications.rb # workflow
    - application_task.rb # base class
    - login_user.rb
    - register_user.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Verb + Noun
class ProcessOrder < CMDx::Task; end
class SendEmail < CMDx::Task; end
class ValidatePayment < CMDx::Task; end

# Use present tense verbs for actions
class CreateUser < CMDx::Task; end      # ✓ Good
class CreatingUser < CMDx::Task; end    # ❌ Avoid
class UserCreation < CMDx::Task; end    # ❌ Avoid
```

### Style Guide

Follow a style pattern for consistent task design:

```ruby
class ProcessOrder < CMDx::Task

  # 1. Register functions
  register :middleware, CMDx::Middlewares::Correlate
  register :validator, :domain, DomainValidator

  # 2. Define callbacks
  before_execution :find_order
  on_complete :track_datadog_metrics, if: ->(task) { Current.account.metrics? }

  # 3. Define attributes
  attributes :customer_id
  required :order_id
  optional :store_id

  # 4. Define work
  def work
    order.charge!
    order.ship!

    context.tracking_number = order.tracking_number
  end

  private

  # 5. Define methods
  def find_order
    @order ||= Order.find(order_id)
  end

  def track_datadog_metrics
    DataDog.increment(:order_processed)
  end

end
```

## Attribute Options

Use Rails `with_options` to reduce duplication and improve readability:

```ruby
class UpdateUserProfile < CMDx::Task
  # Apply common options to multiple attributes
  with_options(type: :string, presence: true) do
    attributes :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    required :first_name, :last_name
    optional :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }
  end

  # Nested attributes with shared prefix
  required :address do
    with_options(prefix: :address_) do
      attributes :street, :city, :postal_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :state, type: :string
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
# /*cmdx_task_class:ProcessOrderTask,cmdx_chain_id:018c2b95-b764-7615*/ SELECT * FROM orders WHERE id = 1
```

---
