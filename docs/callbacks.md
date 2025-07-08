# Callbacks

Callbacks (callbacks) provide precise control over task execution lifecycle, running custom logic at
specific transition points. Callback callables have access to the same context and result information
as the `call` method, enabling rich integration patterns.

## Table of Contents

- [TLDR](#tldr)
- [Overview](#overview)
- [Callback Declaration](#callback-declaration)
- [Callback Classes](#callback-classes)
- [Available Callbacks](#available-callbacks)
  - [Validation Callbacks](#validation-callbacks)
  - [Execution Callbacks](#execution-callbacks)
  - [State Callbacks](#state-callbacks)
  - [Status Callbacks](#status-callbacks)
  - [Outcome Callbacks](#outcome-callbacks)
- [Execution Order](#execution-order)
- [Conditional Execution](#conditional-execution)
- [Callback Inheritance](#callback-inheritance)

## TLDR

- **Purpose** - Execute custom logic at specific points in task lifecycle
- **Declaration** - Use method names, procs, class instances, or blocks
- **Callback types** - Validation, execution, state, status, and outcome callbacks
- **Execution order** - Runs in precise lifecycle order (before_execution → validation → call → status → after_execution)
- **Conditional** - Support `:if` and `:unless` options for conditional execution
- **Inheritance** - Callbacks are inherited, perfect for global patterns

> [!TIP]
> Callbacks are inheritable, making them perfect for setting up global logic execution patterns like tracking markers, account plan checks, or logging standards.

## Overview

Callbacks can be declared in multiple ways: method names, procs/lambdas, Callback class instances, or blocks.

```ruby
class ProcessOrderTask < CMDx::Task
  # Method name declaration
  after_validation :verify_order_data

  # Proc/lambda declaration
  on_complete -> { send_telemetry_data }

  # Callback class declaration
  before_execution LoggingCallback.new(:debug)
  on_success NotificationCallback.new([:email, :slack])

  # Multiple callbacks for same event
  on_success :increment_counter, :send_notification

  # Conditional execution
  on_failed :alert_support, if: :critical_order?
  after_execution :cleanup_resources, unless: :preserve_data?

  # Block declaration
  before_execution do
    context.processing_start = Time.now
  end

  def call
    context.order = Order.find(order_id)
    context.order.process!
  end

  private

  def critical_order?
    context.order.value > 10_000
  end

  def preserve_data?
    Rails.env.development?
  end
end
```

## Callback Classes

For complex callback logic or reusable patterns, you can create Callback classes similar to Middleware classes. Callback classes inherit from `CMDx::Callback` and implement the `call(task, type)` method.

```ruby
class NotificationCallback < CMDx::Callback
  def initialize(channels)
    @channels = Array(channels)
  end

  def call(task, type)
    return unless type == :on_success

    @channels.each do |channel|
      NotificationService.send(channel, "Task #{task.class.name} completed")
    end
  end
end
```

## Available Callbacks

### Validation Callbacks

Execute around parameter validation:

- `before_validation` - Before parameter validation
- `after_validation` - After successful parameter validation

### Execution Callbacks

Execute around task logic:

- `before_execution` - Before task logic begins
- `after_execution` - After task logic completes (success or failure)

### State Callbacks

Execute based on execution state:

- `on_executing` - Task begins running
- `on_complete` - Task completes successfully
- `on_interrupted` - Task is halted (skip/failure)
- `on_executed` - Task finishes (complete or interrupted)

### Status Callbacks

Execute based on execution status:

- `on_success` - Task succeeds
- `on_skipped` - Task is skipped
- `on_failed` - Task fails

### Outcome Callbacks

Execute based on outcome classification:

- `on_good` - Positive outcomes (success or skipped)
- `on_bad` - Negative outcomes (skipped or failed)

## Execution Order

Callbacks execute in precise order during task lifecycle:

> [!IMPORTANT]
> Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

```ruby
1. before_execution            # Setup and preparation
2. on_executing                # Task begins running
3. before_validation           # Pre-validation setup
4. after_validation            # Post-validation logic
5. [call method]               # Your business logic
6. on_[complete|interrupted]   # Based on execution state
7. on_executed                 # Task finished (any outcome)
8. on_[success|skipped|failed] # Based on execution status
9. on_[good|bad]               # Based on outcome classification
10. after_execution            # Cleanup and finalization
```

> [!IMPORTANT]
> Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

## Conditional Execution

Callbacks support conditional execution through `:if` and `:unless` options:

| Option    | Description |
| --------- | ----------- |
| `:if`     | Execute callback only if condition is truthy |
| `:unless` | Execute callback only if condition is falsy |

```ruby
class ProcessPaymentTask < CMDx::Task
  # Method name condition
  on_success :send_receipt, if: :email_enabled?

  # Proc condition
  on_failure :retry_payment, if: -> { retry_count < 3 }

  # String condition (evaluated as method)
  after_execution :log_metrics, unless: "Rails.env.test?"

  # Multiple conditions
  on_complete :expensive_operation, if: :production_env?, unless: :maintenance_mode?

  private

  def email_enabled?
    context.user.email_notifications?
  end

  def production_env?
    Rails.env.production?
  end

  def maintenance_mode?
    SystemStatus.maintenance_mode?
  end
end
```

## Callback Inheritance

Callbacks are inherited from parent classes, enabling application-wide patterns:

```ruby
class ApplicationTask < CMDx::Task
  before_execution :log_task_start  # All tasks get execution logging
  after_execution :log_task_end     # All tasks get completion logging
  on_failed :report_failure         # All tasks get error reporting
  on_success :track_success_metrics # All tasks get success tracking

  private

  def log_task_start
    Rails.logger.info "Starting #{self.class.name}"
  end

  def log_task_end
    Rails.logger.info "Finished #{self.class.name} in #{result.runtime}s"
  end

  def report_failure
    ErrorReporter.notify(result.metadata)
  end

  def track_success_metrics
    Metrics.increment("task.#{self.class.name.underscore}.success")
  end
end

class ProcessOrderTask < ApplicationTask
  before_validation :load_order                     # Specific to order processing
  on_success :send_confirmation                     # Domain-specific success action
  on_failed :refund_payment, if: :payment_captured? # Order-specific failure handling

  def call
    # Inherits all ApplicationTask callbacks plus order-specific ones
    context.order.process!
  end
end
```

> [!TIP]
> Callbacks are inherited by subclasses, making them ideal for setting up global lifecycle patterns across all tasks in your application.

---

- **Prev:** [Parameters - Defaults](parameters/defaults.md)
- **Prev:** [Middlewares](middlewares.md)
