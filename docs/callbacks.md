# Callbacks

Callbacks provide precise control over task execution lifecycle, running custom logic at specific transition points. Callback callables have access to the same context and result information as the `execute` method, enabling rich integration patterns.

## Table of Contents

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
- [Error Handling](#error-handling)
- [Callback Inheritance](#callback-inheritance)



## Callback Declaration

Callbacks can be declared using method names, procs/lambdas, Callback class instances, or blocks. All forms have access to the task's context and result.

> [!IMPORTANT]
> Callbacks execute in declaration order (FIFO) and are inherited by subclasses, making them ideal for application-wide patterns.

### Declaration Methods

| Method | Description | Example |
|--------|-------------|---------|
| Method name | References instance method | `on_success :send_email` |
| Proc/Lambda | Inline callable | `on_failed -> { alert_team }` |
| Callback class | Reusable class instance | `before_execution LoggerCallback.new` |
| Block | Inline block | `on_success { increment_counter }` |

```ruby
class ProcessOrder < CMDx::Task
  # Method name
  before_validation :load_order
  after_validation :verify_inventory

  # Proc/lambda
  on_executing -> { context.start_time = Time.current }
  on_complete lambda { Metrics.increment('orders.processed') }

  # Callback class
  before_execution AuditCallback.new(action: :process_order)
  on_success NotificationCallback.new(channels: [:email, :slack])

  # Block
  on_failed do
    ErrorReporter.notify(
      error: result.metadata[:error],
      order_id: context.order_id,
      user_id: context.user_id
    )
  end

  # Multiple callbacks
  on_success :update_inventory, :send_confirmation, :log_success

  def work
    context.order = Order.find(context.order_id)
    context.order.process!
  end

  private

  def load_order
    context.order ||= Order.find(context.order_id)
  end

  def verify_inventory
    raise "Insufficient inventory" unless context.order.items_available?
  end
end
```

## Callback Classes

> [!TIP]
> Create reusable Callback classes for complex logic or cross-cutting concerns. Callback classes inherit from `CMDx::Callback` and implement `call(task, type)`.

```ruby
class AuditCallback < CMDx::Callback
  def initialize(action:, level: :info)
    @action = action
    @level = level
  end

  def work(task, type)
    AuditLogger.log(
      level: @level,
      action: @action,
      task: task.class.name,
      callback_type: type,
      user_id: task.context.current_user&.id,
      timestamp: Time.current
    )
  end
end

class NotificationCallback < CMDx::Callback
  def initialize(channels:, template: nil)
    @channels = Array(channels)
    @template = template
  end

  def work(task, type)
    return unless should_notify?(type)

    @channels.each do |channel|
      NotificationService.send(
        channel: channel,
        template: @template || default_template(type),
        data: extract_notification_data(task)
      )
    end
  end

  private

  def should_notify?(type)
    %i[on_success on_failed].include?(type)
  end

  def default_template(type)
    type == :on_success ? :task_success : :task_failure
  end

  def extract_notification_data(task)
    {
      task_name: task.class.name,
      status: task.result.status,
      runtime: task.result.runtime,
      context: task.context.to_h.except(:sensitive_data)
    }
  end
end
```

## Available Callbacks

### Validation Callbacks

Execute around parameter validation:

| Callback | Timing | Description |
|----------|--------|-------------|
| `before_validation` | Before validation | Setup validation context |
| `after_validation` | After successful validation | Post-validation logic |

```ruby
class CreateUser < CMDx::Task
  before_validation :normalize_email
  after_validation :check_user_limits

  required :email, type: :string
  required :plan, type: :string

  def work
    User.create!(email: email, plan: plan)
  end

  private

  def normalize_email
    context.email = email.downcase.strip
  end

  def check_user_limits
    current_users = User.where(plan: plan).count
    plan_limit = Plan.find_by(name: plan).user_limit

    if current_users >= plan_limit
      throw(:skip, Plan user limit reached")
    end
  end
end
```

### Execution Callbacks

Execute around task logic:

| Callback | Timing | Description |
|----------|--------|-------------|
| `before_execution` | Before `execute` method | Setup and preparation |
| `after_execution` | After `execute` completes | Cleanup and finalization |

```ruby
class ProcessPayment < CMDx::Task
  before_execution :acquire_payment_lock
  after_execution :release_payment_lock

  def work
    Payment.process!(context.payment_data)
  end

  private

  def acquire_payment_lock
    context.lock_key = "payment:#{context.payment_id}"
    Redis.current.set(context.lock_key, "locked", ex: 300)
  end

  def release_payment_lock
    Redis.current.del(context.lock_key) if context.lock_key
  end
end
```

### State Callbacks

Execute based on execution state:

| Callback | Condition | Description |
|----------|-----------|-------------|
| `on_executing` | Task begins running | Track execution start |
| `on_complete` | Task completes successfully | Handle successful completion |
| `on_interrupted` | Task is halted (skip/failure) | Handle interruptions |
| `on_executed` | Task finishes (any outcome) | Post-execution logic |

### Status Callbacks

Execute based on execution status:

| Callback | Status | Description |
|----------|--------|-------------|
| `on_success` | Task succeeds | Handle success |
| `on_skipped` | Task is skipped | Handle skips |
| `on_failed` | Task fails | Handle failures |

### Outcome Callbacks

Execute based on outcome classification:

| Callback | Outcomes | Description |
|----------|----------|-------------|
| `on_good` | Success or skipped | Positive outcomes |
| `on_bad` | Failed | Negative outcomes |

```ruby
class EmailCampaign < CMDx::Task
  on_executing -> { Metrics.increment('campaigns.started') }
  on_complete :track_completion
  on_interrupted :handle_interruption

  on_success :schedule_followup
  on_skipped :log_skip_reason
  on_failed :alert_marketing_team

  on_good -> { Metrics.increment('campaigns.positive_outcome') }
  on_bad :create_incident_ticket

  def work
    EmailService.send_campaign(context.campaign_data)
  end

  private

  def track_completion
    Campaign.find(context.campaign_id).update!(
      sent_at: Time.current,
      recipient_count: context.recipients.size
    )
  end

  def handle_interruption
    Campaign.find(context.campaign_id).update!(status: :interrupted)
  end
end
```

## Execution Order

> [!IMPORTANT]
> Callbacks execute in precise lifecycle order. Multiple callbacks of the same type execute in declaration order (FIFO: first in, first out).

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

## Conditional Execution

> [!TIP]
> Use `:if` and `:unless` options for conditional callback execution. Conditions can be method names, procs, or strings.

| Option | Description | Example |
|--------|-------------|---------|
| `:if` | Execute if condition is truthy | `if: :production_env?` |
| `:unless` | Execute if condition is falsy | `unless: :maintenance_mode?` |

```ruby
class ProcessOrder < CMDx::Task
  # Method name conditions
  on_success :send_receipt, if: :email_enabled?
  on_failed :retry_payment, unless: :max_retries_reached?

  # Proc conditions
  after_execution :log_metrics, if: -> { Rails.env.production? }
  on_success :expensive_operation, unless: -> { SystemStatus.overloaded? }

  # String conditions (evaluated as methods)
  on_complete :update_analytics, if: "tracking_enabled?"

  # Multiple conditions
  on_failed :escalate_to_support, if: :critical_order?, unless: :business_hours?

  # Complex conditional logic
  on_success :trigger_automation, if: :automation_conditions_met?

  def work
    Order.process!(context.order_data)
  end

  private

  def email_enabled?
    context.user.email_notifications? && !context.user.email.blank?
  end

  def max_retries_reached?
    context.retry_count >= 3
  end

  def critical_order?
    context.order_value > 10_000 || context.priority == :high
  end

  def business_hours?
    Time.current.hour.between?(9, 17) && Time.current.weekday?
  end

  def automation_conditions_met?
    context.order_type == :subscription &&
    context.user.plan.automation_enabled? &&
    !SystemStatus.maintenance_mode?
  end
end
```

## Error Handling

> [!WARNING]
> Callback errors can interrupt task execution. Use proper error handling and consider callback isolation for non-critical operations.

### Callback Error Behavior

```ruby
class ProcessData < CMDx::Task
  before_execution :critical_setup     # Error stops execution
  on_success :send_notification       # Error stops callback chain
  after_execution :cleanup_resources   # Always runs

  def work
    ProcessingService.handle(context.data)
  end

  private

  def critical_setup
    # Critical callback - let errors bubble up
    context.processor = ProcessorService.initialize_secure_processor
  end

  def send_notification
    # Non-critical callback - handle errors gracefully
    NotificationService.send(context.notification_data)
  rescue NotificationService::Error => e
    Rails.logger.warn "Notification failed: #{e.message}"
    # Don't re-raise - allow other callbacks to continue
  end

  def cleanup_resources
    # Cleanup callback - always handle errors
    context.processor&.cleanup
  rescue => e
    Rails.logger.error "Cleanup failed: #{e.message}"
    # Log but don't re-raise
  end
end
```

### Isolating Non-Critical Callbacks

```ruby
class ResilientCallback < CMDx::Callback
  def initialize(callback_proc, isolate: false)
    @callback_proc = callback_proc
    @isolate = isolate
  end

  def work(task, type)
    if @isolate
      begin
        @callback_proc.execute(task, type)
      rescue => e
        Rails.logger.warn "Isolated callback failed: #{e.message}"
      end
    else
      @callback_proc.execute(task, type)
    end
  end
end

class ProcessOrder < CMDx::Task
  # Critical callback
  before_execution :validate_payment_method

  # Isolated non-critical callback
  on_success ResilientCallback.new(
    -> (task, type) { AnalyticsService.track_order(task.context.order_id) },
    isolate: true
  )

  def work
    Order.process!(context.order_data)
  end
end
```

## Callback Inheritance

> [!NOTE]
> Callbacks are inherited from parent classes, enabling application-wide patterns. Child classes can add additional callbacks or override inherited behavior.

```ruby
class ApplicationTask < CMDx::Task
  # Global logging
  before_execution :log_task_start
  after_execution :log_task_end

  # Global error handling
  on_failed :report_failure

  # Global metrics
  on_success :track_success_metrics
  on_executed :track_execution_metrics

  private

  def log_task_start
    Rails.logger.info "Starting #{self.class.name} with context: #{context.to_h.except(:sensitive_data)}"
  end

  def log_task_end
    Rails.logger.info "Finished #{self.class.name} in #{result.runtime}ms with status: #{result.status}"
  end

  def report_failure
    ErrorReporter.notify(
      task: self.class.name,
      error: result.reason,
      context: context.to_h.except(:sensitive_data),
      backtrace: result.metadata[:backtrace]
    )
  end

  def track_success_metrics
    Metrics.increment("task.#{self.class.name.underscore}.success")
  end

  def track_execution_metrics
    Metrics.histogram("task.#{self.class.name.underscore}.runtime", result.runtime)
  end
end

class ProcessPayment < ApplicationTask
  # Inherits all ApplicationTask callbacks
  # Plus payment-specific callbacks

  before_validation :load_payment_method
  on_success :send_receipt
  on_failed :refund_payment, if: :payment_captured?

  def work
    # Inherits global logging, error handling, and metrics
    # Plus payment-specific behavior
    PaymentProcessor.charge(context.payment_data)
  end

  private

  def load_payment_method
    context.payment_method = PaymentMethod.find(context.payment_method_id)
  end

  def send_receipt
    ReceiptService.send(
      user: context.user,
      payment: context.payment,
      template: :payment_success
    )
  end

  def payment_captured?
    context.payment&.status == :captured
  end

  def refund_payment
    RefundService.process(
      payment: context.payment,
      reason: :task_failure,
      amount: context.payment.amount
    )
  end
end
```

---

- **Prev:** [Parameters - Defaults](parameters/defaults.md)
- **Next:** [Middlewares](middlewares.md)
