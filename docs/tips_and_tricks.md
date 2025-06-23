# Tips & Tricks

This guide covers advanced patterns, optimization techniques, and best practices for getting the most out of CMDx in production applications.

## Project Organization

### Directory Structure

Create a well-organized command structure for maintainable applications:

```txt
/app
  /commands
    /orders
      - process_order_task.rb
      - validate_order_task.rb
      - fulfill_order_task.rb
      - batch_process_orders.rb
    /notifications
      - send_email_task.rb
      - send_sms_task.rb
      - post_slack_message_task.rb
      - batch_deliver_notifications.rb
    /payments
      - charge_payment_task.rb
      - refund_payment_task.rb
      - validate_payment_method_task.rb
    - application_task.rb
    - application_batch.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Tasks: Verb + Noun + Task
class ProcessOrderTask < CMDx::Task; end
class SendEmailTask < CMDx::Task; end
class ValidatePaymentTask < CMDx::Task; end

# Batches: Batch + Verb + Noun
class BatchProcessOrders < CMDx::Batch; end
class BatchDeliverNotifications < CMDx::Batch; end

# Use present tense verbs for actions
class CreateUserTask < CMDx::Task; end      # ✓ Good
class CreatingUserTask < CMDx::Task; end    # ❌ Avoid
class UserCreationTask < CMDx::Task; end    # ❌ Avoid
```

## Advanced Configuration

### Environment-Specific Setup

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  case Rails.env
  when 'development'
    config.logger = Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new)
    config.logger.level = Logger::DEBUG
    config.task_timeout = nil  # No timeouts in development

  when 'test'
    config.logger = Logger.new("log/test.log", formatter: CMDx::LogFormatters::Line.new)
    config.logger.level = Logger::WARN
    config.task_timeout = 5    # Fast timeouts for tests

  when 'production'
    config.logger = Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Logstash.new)
    config.logger.level = Logger::INFO
    config.task_timeout = 120  # 2 minutes per task
    config.batch_timeout = 600 # 10 minutes per batch
  end
end
```

### Dynamic Configuration

```ruby
# Environment-based configuration
CMDx.configure do |config|
  config.task_timeout = ENV.fetch('CMDX_TASK_TIMEOUT', 60).to_i
  config.batch_timeout = ENV.fetch('CMDX_BATCH_TIMEOUT', 300).to_i

  # Feature flags
  config.logger.level = ENV['CMDX_DEBUG'] ? Logger::DEBUG : Logger::INFO

  # External service configuration
  if ENV['LOGSTASH_ENABLED']
    config.logger.formatter = CMDx::LogFormatters::Logstash.new
  end
end
```

## Parameter Optimization

### Efficient Parameter Definitions

Use Rails `with_options` to reduce duplication and improve readability:

```ruby
class UpdateUserProfileTask < CMDx::Task
  # Apply common options to multiple parameters
  with_options(type: :string, presence: true) do
    required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    optional :first_name, :last_name
    optional :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }
  end

  # Nested parameters with shared prefix
  required :address do
    with_options(prefix: :address_) do
      required :street, :city, :postal_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :state, type: :string
    end
  end

  # Shared validation rules
  with_options(type: :integer, numericality: { greater_than: 0 }) do
    optional :age, numericality: { less_than: 150 }
    optional :years_experience, numericality: { less_than: 80 }
  end

  def call
    # Implementation
  end
end
```

### Performance-Optimized Parameters

```ruby
class ProcessOptimizedTask < CMDx::Task
  # Use lazy evaluation for expensive defaults
  optional :timestamp, type: :time, default: -> { Time.current }
  optional :uuid, type: :string, default: -> { SecureRandom.uuid }

  # Use simple defaults for common cases
  optional :page_size, type: :integer, default: 20
  optional :sort_order, type: :string, default: "asc"
  optional :include_deleted, type: :boolean, default: false

  def call
    # Implementation
  end
end
```

## Task Composition Patterns

### Base Task Architecture

```ruby
# app/commands/application_task.rb
class ApplicationTask < CMDx::Task
  # Global hooks for all tasks
  before_execution :start_performance_tracking
  after_execution :end_performance_tracking
  on_failed :report_failure_to_monitoring

  # Global settings
  task_settings!(
    tags: [:application],
    task_timeout: 60
  )

  private

  def start_performance_tracking
    context.performance_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def end_performance_tracking
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - context.performance_start
    ApplicationMetrics.record_task_duration(self.class.name, duration)
  end

  def report_failure_to_monitoring
    ErrorReporter.notify(
      error: StandardError.new(result.metadata[:reason] || "Task failed"),
      context: {
        task: self.class.name,
        metadata: result.metadata,
        runtime: result.runtime
      }
    )
  end
end

# Domain-specific base tasks
class OrderTask < ApplicationTask
  task_settings!(tags: [:order])

  before_validation :load_order

  private

  def load_order
    context.order = Order.find(context.order_id) if context.order_id
  end
end

class PaymentTask < ApplicationTask
  task_settings!(tags: [:payment], task_timeout: 30)

  before_validation :validate_payment_context

  private

  def validate_payment_context
    unless context.payment_method_id || context.payment_method
      fail!("Payment method required for payment tasks")
    end
  end
end
```

### Task Tagging and Categorization

```ruby
class ProcessOrderTask < OrderTask
  # Multiple tags for categorization
  task_settings!(
    tags: [:order, :payment, :fulfillment, :critical],
    task_timeout: 120
  )

  def call
    # Implementation
  end
end

# Query tasks by tags (useful for monitoring)
class TaskAnalyzer
  def self.analyze_performance_by_category
    # In a real implementation, you'd query your logging/monitoring system
    critical_tasks = find_tasks_with_tag(:critical)
    payment_tasks = find_tasks_with_tag(:payment)

    # Analyze performance patterns
  end
end
```

## Performance Optimization

### Efficient Context Usage

```ruby
class ProcessOptimizedContextTask < CMDx::Task
  def call
    # Cache expensive lookups in context
    context.user ||= User.find(context.user_id)
    context.organization ||= context.user.organization

    # Use context for data pipeline between methods
    load_order_data
    validate_business_rules
    process_payment
    fulfill_order
  end

  private

  def load_order_data
    # Store intermediate results in context
    context.order_items = context.order.items.includes(:product)
    context.total_amount = context.order_items.sum(&:total_price)
  end

  def validate_business_rules
    # Access cached data from context
    if context.total_amount > context.user.credit_limit
      fail!("Order exceeds credit limit",
            amount: context.total_amount,
            limit: context.user.credit_limit)
    end
  end
end
```

### Memory-Efficient Batch Processing

```ruby
class BatchProcessLargeDataset < CMDx::Batch
  task_settings!(batch_timeout: 3600) # 1 hour for large datasets

  # Process in chunks to avoid memory issues
  process ProcessChunkDataTask, if: :has_more_data?
  process ProcessChunkTask
  process CleanupChunkTask
  process ProcessChunkDataTask, if: :has_more_data? # Repeat until done

  private

  def has_more_data?
    context.current_offset < context.total_records
  end
end

class ProcessChunkDataTask < CMDx::Task
  def call
    # Process data in small chunks
    chunk_size = 1000
    offset = context.current_offset || 0

    context.current_chunk = LargeDataset
      .limit(chunk_size)
      .offset(offset)
      .pluck(:id, :data)

    context.current_offset = offset + chunk_size

    # Skip if no more data
    skip!("No more data to process") if context.current_chunk.empty?
  end
end
```

## Advanced Error Handling

### Sophisticated Retry Logic

```ruby
class ProcessResilientTask < CMDx::Task
  MAX_RETRIES = 3
  RETRY_DELAY = [1, 2, 4] # Exponential backoff

  def call
    attempt = context.attempt || 0

    begin
      perform_risky_operation
    rescue Net::TimeoutError, Errno::ECONNREFUSED => e
      if attempt < MAX_RETRIES
        context.attempt = attempt + 1
        sleep(RETRY_DELAY[attempt])
        retry
      else
        fail!("Max retries exceeded",
              original_error: e.message,
              attempts: attempt + 1)
      end
    rescue StandardError => e
      # Don't retry for other errors
      fail!("Unrecoverable error: #{e.message}",
            original_error: e.class.name)
    end
  end
end
```

### Graceful Degradation

```ruby
class IntegrateServiceTask < CMDx::Task
  def call
    begin
      result = primary_service.call(context.data)
      context.service_result = result
    rescue Net::TimeoutError
      # Try backup service
      logger.warn "Primary service timeout, trying backup"
      context.service_result = backup_service.call(context.data)
      context.used_backup = true
    rescue StandardError => e
      # Log error but continue with degraded functionality
      logger.error "Service integration failed: #{e.message}"
      context.service_available = false
      # Task succeeds even without external service
    end
  end
end
```

## Monitoring and Observability

### ActiveRecord Query Tagging

Automatically tag SQL queries for better debugging:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class
config.active_record.query_log_tags << :cmdx_run_id

# app/commands/application_task.rb
class ApplicationTask < CMDx::Task
  before_execution :set_execution_context

  private

  def set_execution_context
    ActiveSupport::ExecutionContext.set(
      cmdx_task_class: self.class.name,
      cmdx_run_id: run.id
    )
  end
end

# SQL queries will now include comments like:
# /*cmdx_task_class:ProcessOrderTask,cmdx_run_id:018c2b95-b764-7615*/ SELECT * FROM orders WHERE id = 1
```

### Custom Metrics Integration

```ruby
class ProcessMetricsIntegratedTask < CMDx::Task
  before_execution :start_metrics
  after_execution :finish_metrics
  on_success :record_success_metrics
  on_failed :record_failure_metrics

  private

  def start_metrics
    @metrics_timer = ApplicationMetrics.start_timer("task.#{self.class.name.underscore}")
    ApplicationMetrics.increment("task.#{self.class.name.underscore}.started")
  end

  def finish_metrics
    @metrics_timer&.stop
    ApplicationMetrics.histogram("task.#{self.class.name.underscore}.runtime", result.runtime)
  end

  def record_success_metrics
    ApplicationMetrics.increment("task.#{self.class.name.underscore}.success")

    # Record business metrics
    if context.order
      ApplicationMetrics.histogram("order.value", context.order.total_value)
      ApplicationMetrics.increment("order.processed")
    end
  end

  def record_failure_metrics
    ApplicationMetrics.increment("task.#{self.class.name.underscore}.failed")
    ApplicationMetrics.increment("task.#{self.class.name.underscore}.failed.#{result.metadata[:error_code]}")
  end
end
```

### Health Check Integration

```ruby
class CheckHealthTask < CMDx::Task
  task_settings!(task_timeout: 5)

  def call
    checks = [
      check_database_connection,
      check_redis_connection,
      check_external_apis
    ]

    failed_checks = checks.reject(&:healthy?)

    if failed_checks.any?
      fail!("Health check failed",
            failed_services: failed_checks.map(&:name),
            healthy_services: checks.select(&:healthy?).map(&:name))
    else
      context.all_systems_healthy = true
    end
  end

  private

  def check_database_connection
    HealthCheck.new("database") { ActiveRecord::Base.connection.execute("SELECT 1") }
  end

  def check_redis_connection
    HealthCheck.new("redis") { Redis.current.ping }
  end

  def check_external_apis
    HealthCheck.new("external_api") { ExternalApiClient.health_check }
  end
end

class HealthCheck
  attr_reader :name

  def initialize(name, &check)
    @name = name
    @check = check
    @healthy = nil
  end

  def healthy?
    return @healthy unless @healthy.nil?

    @healthy = begin
      @check.call
      true
    rescue StandardError
      false
    end
  end
end
```

## Testing Strategies

### Comprehensive Task Testing

```ruby
RSpec.describe ProcessOrderTask do
  describe "#call" do
    let(:order) { create(:order, status: :pending) }
    let(:params) { { order_id: order.id, user_id: order.user_id } }

    context "successful processing" do
      it "processes the order successfully" do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.context.order).to eq(order)
        expect(order.reload.status).to eq("processed")
      end

      it "records processing metrics" do
        expect(ApplicationMetrics).to receive(:record_task_duration)
        described_class.call(params)
      end
    end

    context "when order is already processed" do
      before { order.update!(status: :processed) }

      it "skips processing" do
        result = described_class.call(params)

        expect(result).to be_skipped
        expect(result.metadata[:reason]).to include("already processed")
      end
    end

    context "when payment fails" do
      before do
        allow_any_instance_of(PaymentService).to receive(:charge)
          .and_raise(PaymentService::InsufficientFundsError)
      end

      it "fails with payment error" do
        result = described_class.call(params)

        expect(result).to be_failed
        expect(result.metadata[:error_code]).to eq("INSUFFICIENT_FUNDS")
      end
    end
  end

  describe "hooks" do
    let(:task) { described_class.new(params) }

    it "executes hooks in correct order" do
      expect(task).to receive(:start_performance_tracking).ordered
      expect(task).to receive(:load_order).ordered
      expect(task).to receive(:end_performance_tracking).ordered

      task.call
    end
  end
end
```

### Integration Testing

```ruby
RSpec.describe "Order Processing Workflow" do
  it "processes complete order workflow" do
    order = create(:order, :with_items)
    user = order.user

    # Execute the complete workflow
    result = BatchProcessOrders.call(
      order_id: order.id,
      user_id: user.id,
      payment_method_id: user.default_payment_method.id
    )

    # Verify end-to-end success
    expect(result).to be_success
    expect(order.reload).to be_processed
    expect(order.fulfillment).to be_present
    expect(order.tracking_number).to be_present

    # Verify side effects
    expect(InventoryService.current_stock(order.items.first.product)).to eq(
      initial_stock - order.items.first.quantity
    )
    expect(NotificationService).to have_received(:send_confirmation)
  end
end
```

## Production Deployment

### Configuration Management

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  # Use environment variables for production settings
  config.task_timeout = ENV.fetch('CMDX_TASK_TIMEOUT', 60).to_i
  config.batch_timeout = ENV.fetch('CMDX_BATCH_TIMEOUT', 300).to_i

  # Configure logging based on environment
  if ENV['RAILS_LOG_TO_STDOUT'].present?
    config.logger = Logger.new(STDOUT)
  else
    config.logger = Logger.new(Rails.root.join('log', 'cmdx.log'))
  end

  # Set log level
  config.logger.level = ENV.fetch('CMDX_LOG_LEVEL', 'INFO').constantize

  # Use appropriate formatter for environment
  if ENV['LOGSTASH_ENABLED']
    config.logger.formatter = CMDx::LogFormatters::Logstash.new
  elsif ENV['JSON_LOGGING']
    config.logger.formatter = CMDx::LogFormatters::Json.new
  else
    config.logger.formatter = CMDx::LogFormatters::Line.new
  end
end
```

### Monitoring Setup

```ruby
# config/initializers/cmdx_monitoring.rb
if Rails.env.production?
  # Application Performance Monitoring
  class CMDxAPMIntegration < ApplicationTask
    after_execution :send_apm_metrics

    private

    def send_apm_metrics
      NewRelic::Agent.record_metric(
        "Custom/CMDx/#{self.class.name}/Duration",
        result.runtime
      )

      if result.failed?
        NewRelic::Agent.notice_error(
          StandardError.new(result.metadata[:reason] || "Task failed"),
          custom_params: {
            task_class: self.class.name,
            task_metadata: result.metadata,
            run_id: run.id
          }
        )
      end
    end
  end

  # Structured logging for log aggregation
  CMDx.configure do |config|
    config.logger.formatter = CMDx::LogFormatters::Logstash.new
  end
end
```

## Debugging Techniques

### Debug Mode Configuration

```ruby
class ProcessDebugTask < CMDx::Task
  task_settings!(
    logger: Rails.env.development? ? Logger.new(STDOUT) : Rails.logger,
    log_level: Rails.env.development? ? Logger::DEBUG : Logger::INFO
  )

  def call
    # Enhanced logging in development
    if Rails.env.development?
      logger.debug "Task started with context: #{context.to_h.inspect}"
      logger.debug "Available methods: #{self.class.instance_methods(false)}"
    end

    # Implementation

    logger.debug "Task completed successfully" if Rails.env.development?
  end
end
```

### Runtime Inspection

```ruby
class ProcessInspectableTask < CMDx::Task
  def call
    # Use built-in runtime measurement
    processing_time = Utils::MonotonicRuntime.call do
      expensive_operation
    end

    logger.info "Expensive operation completed in #{processing_time}ms"

    # Store timing for analysis
    context.operation_timings = {
      expensive_operation: processing_time,
      total_runtime: result.runtime
    }
  end

  private

  def expensive_operation
    # Simulate expensive work
    sleep(0.1)
  end
end
```

## Best Practices Summary

### Design Principles

- **Single Responsibility**: Each task should do one thing well
- **Composition over Inheritance**: Combine simple tasks rather than creating complex hierarchies
- **Explicit Dependencies**: Make task dependencies clear through parameters
- **Fail Fast**: Validate early and provide clear error messages
- **Idempotency**: Design tasks to be safely re-runnable

### Performance Guidelines

- Use lazy evaluation for expensive defaults
- Cache expensive lookups in context
- Process large datasets in chunks
- Monitor and optimize task execution times
- Use appropriate timeout values

### Error Handling

- Provide detailed error metadata
- Use skips for expected non-error conditions
- Implement retry logic for transient failures
- Log errors with sufficient context for debugging
- Use graceful degradation when possible

### Testing

- Test all execution paths (success, skip, failure)
- Verify hook execution order
- Test parameter validation thoroughly
- Use integration tests for complex workflows
- Mock external dependencies appropriately

---

- **Prev:** [Logging](https://github.com/drexed/cmdx/blob/main/docs/logging.md)
- **Next:** [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)
