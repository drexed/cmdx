# Hooks

Hooks (callbacks) provide precise control over task execution lifecycle, running custom logic at specific transition points. Hook callables have access to the same context and result information as the `call` method, enabling rich integration patterns.

## Key Features

- **Lifecycle Integration**: Execute logic at precise execution points
- **Conditional Execution**: Use `:if` and `:unless` conditions for dynamic behavior
- **Inheritance Support**: Hooks are inherited, enabling global logic patterns
- **Multiple Declarations**: Register multiple hooks for the same event
- **Flexible Callables**: Support method names, procs, lambdas, and any callable object

> [!TIP]
> Hooks are inheritable, making them perfect for setting up global logic execution patterns like tracking markers, account plan checks, or logging standards.

## Hook Declaration

```ruby
class ProcessOrderTask < CMDx::Task
  # Method name declaration
  after_validation :verify_order_data

  # Proc/lambda declaration
  on_complete -> { send_telemetry_data }

  # Multiple hooks for same event
  on_success :increment_counter, :send_notification

  # Conditional execution
  on_failure :alert_support, if: :critical_order?
  after_execution :cleanup_resources, unless: :preserve_data?

  # Block declaration
  before_execution do
    context.processing_start = Time.current
  end

  def call
    # Business logic implementation
  end

  private

  def critical_order?
    context.order_value > 10_000
  end

  def preserve_data?
    Rails.env.development?
  end
end
```

## Available Hooks

CMDx provides comprehensive lifecycle hooks organized by execution phase:

### Validation Hooks
- `before_validation` - Execute before parameter validation
- `after_validation` - Execute after successful parameter validation

### Execution Hooks
- `before_execution` - Execute before task logic begins
- `after_execution` - Execute after task logic completes (success or failure)

### State Hooks
- `on_executing` - Execute when task begins running
- `on_complete` - Execute when task completes successfully
- `on_interrupted` - Execute when task is halted (skip/failure)
- `on_executed` - Execute when task finishes (complete or interrupted)

### Status Hooks
- `on_success` - Execute when task succeeds
- `on_skipped` - Execute when task is skipped
- `on_failed` - Execute when task fails

### Outcome Hooks
- `on_good` - Execute for positive outcomes (success or skipped)
- `on_bad` - Execute for negative outcomes (skipped or failed)

## Execution Order

Hooks execute in a precise order during task lifecycle:

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
> Multiple hooks of the same type execute in declaration order (FIFO: first in, first out).

## Conditional Execution

Hooks support conditional execution through `:if` and `:unless` options:

| Option    | Description |
| --------- | ----------- |
| `:if`     | Execute hook only if condition is truthy |
| `:unless` | Execute hook only if condition is falsy |

### Condition Types

```ruby
class ProcessConditionalHooksTask < CMDx::Task
  # Method name condition
  on_success :send_email, if: :email_enabled?

  # Proc condition
  on_failure :retry_task, if: -> { retry_count < 3 }

  # String condition (evaluated as method)
  after_execution :log_metrics, unless: "Rails.env.test?"

  # Multiple conditions (all must be true for :if)
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

## Hook Inheritance

Hooks are inherited from parent classes, enabling powerful architectural patterns:

```ruby
class ApplicationTask < CMDx::Task
  # Global hooks for all tasks
  before_execution :log_task_start
  after_execution :log_task_end
  on_failed :report_failure

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
end

class ProcessOrderTask < ApplicationTask
  # Inherits all ApplicationTask hooks plus these specific ones
  before_validation :load_order
  on_success :send_confirmation
  on_failed :refund_payment, if: :payment_captured?

  def call
    # Business logic
  end
end
```

## Practical Examples

### Monitoring and Metrics

```ruby
class CollectMetricsTask < CMDx::Task
  before_execution :start_timer
  after_execution :record_metrics
  on_success :increment_success_counter
  on_failed :increment_failure_counter

  private

  def start_timer
    context.start_time = Time.current
  end

  def record_metrics
    MetricsService.record_execution(
      task: self.class.name,
      duration: Time.current - context.start_time,
      status: result.status
    )
  end

  def increment_success_counter
    MetricsService.increment("#{self.class.name.underscore}.success")
  end

  def increment_failure_counter
    MetricsService.increment("#{self.class.name.underscore}.failure")
  end
end
```

### Resource Management

```ruby
class ManageResourceTask < CMDx::Task
  before_execution :acquire_resources
  after_execution :release_resources
  on_failed :cleanup_partial_state

  private

  def acquire_resources
    context.database_connection = DatabasePool.checkout
    context.temp_files = []
  end

  def release_resources
    DatabasePool.checkin(context.database_connection) if context.database_connection
    cleanup_temp_files
  end

  def cleanup_partial_state
    # Clean up any partial state on failure
    context.temp_files&.each { |file| File.delete(file) if File.exist?(file) }
  end

  def cleanup_temp_files
    context.temp_files&.each { |file| File.delete(file) if File.exist?(file) }
  end
end
```

### Notification Patterns

```ruby
class SendNotificationTask < CMDx::Task
  on_success :send_success_notification
  on_skipped :send_skip_notification
  on_failed :send_failure_notification, :alert_support

  # Conditional notifications
  on_success :send_sms, if: :sms_enabled?
  on_success :send_email, if: :email_enabled?

  private

  def send_success_notification
    NotificationService.success(
      user: context.user,
      message: "Task completed successfully",
      metadata: result.metadata
    )
  end

  def send_skip_notification
    NotificationService.info(
      user: context.user,
      message: "Task was skipped: #{result.metadata[:reason]}"
    )
  end

  def send_failure_notification
    NotificationService.error(
      user: context.user,
      message: "Task failed: #{result.metadata[:reason]}"
    )
  end

  def alert_support
    return unless result.metadata[:severity] == 'critical'

    SupportAlertService.critical_failure(
      task: self.class.name,
      user: context.user,
      error: result.metadata
    )
  end

  def sms_enabled?
    context.user.sms_notifications?
  end

  def email_enabled?
    context.user.email_notifications?
  end
end
```

## Advanced Patterns

### Hook Composition

```ruby
class ProcessCompositeTask < CMDx::Task
  # Multiple hooks with different conditions
  on_success :log_success, :update_cache, :send_notification
  on_success :expensive_operation, if: :should_run_expensive_op?
  on_success :cleanup_cache, unless: :preserve_cache?

  # Chained conditional logic
  on_failed :retry_task, if: :retryable_error?
  on_failed :permanent_failure_handling, unless: :retryable_error?

  private

  def should_run_expensive_op?
    context.priority == 'high' && !Rails.env.test?
  end

  def retryable_error?
    result.metadata[:error_type] == 'temporary'
  end
end
```

### Dynamic Hook Registration

```ruby
class ProcessDynamicHooksTask < CMDx::Task
  # Hooks can be registered dynamically based on configuration
  def self.configure_hooks(config)
    on_success :send_webhook if config.webhook_enabled?
    on_failed :send_slack_alert if config.slack_integration?
    after_execution :log_to_external_service if config.external_logging?
  end
end

# Usage
ProcessDynamicHooksTask.configure_hooks(AppConfig.current)
```

## Best Practices

### Hook Organization

- **Use inheritance** for common patterns across multiple tasks
- **Keep hooks focused** on single responsibilities
- **Use descriptive names** that clearly indicate when and why they run
- **Group related hooks** together in the class definition

### Performance Considerations

- **Avoid expensive operations** in frequently-called hooks
- **Use conditional execution** to skip unnecessary work
- **Consider async processing** for non-critical hook logic
- **Monitor hook execution time** in production

### Error Handling

- **Hooks should not raise exceptions** unless absolutely necessary
- **Use result metadata** to communicate hook outcomes
- **Log hook failures** appropriately for debugging
- **Consider hook failure impact** on overall task execution

### Testing Hooks

```ruby
RSpec.describe ProcessOrderTask do
  describe "hooks" do
    let(:task) { described_class.new(order_id: 123) }

    it "executes success hooks in order" do
      expect(task).to receive(:increment_counter).ordered
      expect(task).to receive(:send_notification).ordered

      task.call
    end

    it "executes conditional hooks appropriately" do
      allow(task).to receive(:critical_order?).and_return(true)
      expect(task).to receive(:alert_support)

      task.fail!("Test failure")
    end
  end
end
```

---

- **Prev:** [Outcomes - States](https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md)
- **Next:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
