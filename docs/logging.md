# Logging

CMDx provides comprehensive automatic logging for task execution with structured data, customizable formatters, and intelligent severity mapping. The framework logs all task results after completion with rich metadata for debugging and monitoring.

## Key Features

- **Automatic Result Logging**: Tasks automatically log their execution results after completion
- **Structured Data**: Rich metadata including execution timing, states, statuses, and failure chains
- **Multiple Formatters**: 8 built-in formatters for different output needs and environments
- **ANSI Colorization**: Enhanced terminal output with color-coded severity and status indicators
- **Configurable Levels**: Global and task-specific log level configuration
- **Thread-Safe**: Designed for concurrent task execution environments

## Log Formatters

CMDx provides 8 built-in log formatters organized into standard and stylized categories:

### Standard Formatters
- **`Line`** - Traditional single-line format similar to Ruby's Logger
- **`Json`** - Compact single-line JSON for structured logging systems
- **`KeyValue`** - Space-separated key=value pairs for easy parsing
- **`Logstash`** - ELK stack compatible JSON with @version and @timestamp fields
- **`Raw`** - Minimal output containing only the message content

### Stylized Formatters (ANSI Colors)
- **`PrettyLine`** - Colorized line format (default)
- **`PrettyJson`** - Human-readable multi-line JSON with syntax highlighting
- **`PrettyKeyValue`** - Colorized key=value pairs for terminal readability

## Sample Output

### Success Result
```txt
I, [2022-07-17T18:43:15.000000 #3784] INFO -- ProcessOrderTask: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=ProcessOrderTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=complete status=success outcome=success metadata={order_id: 123, confirmation: "ABC123"} runtime=0.45 origin=CMDx
```

### Skipped Result
```txt
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ProcessOrderTask: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=ProcessOrderTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=skipped outcome=skipped metadata={reason: "Order already processed", existing_order_id: 456} runtime=0.02 origin=CMDx
```

### Failed Result
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessOrderTask: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=ProcessOrderTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=failed outcome=failed metadata={reason: "Payment validation failed", error_code: "PAYMENT_INVALID", retry_allowed: true} runtime=0.15 origin=CMDx
```

### Failure Chain (Batch/Complex Workflows)
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessOrderBatch: index=0 run_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Batch class=ProcessOrderBatch id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=failed outcome=interrupted metadata={} runtime=0.75 caused_failure={index: 2, class: "ValidatePaymentTask", status: "failed", metadata: {error_code: "INVALID_CARD"}} threw_failure={index: 1, class: "ProcessPaymentTask", status: "failed"} origin=CMDx
```

## Configuration

### Global Configuration

Configure logging globally in your CMDx initializer:

```ruby
CMDx.configure do |config|
  # Basic logger setup
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyLine.new)

  # Production environment example
  config.logger = Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Json.new)
  config.logger.level = Logger::INFO

  # ELK stack integration
  config.logger = Logger.new("log/cmdx-logstash.log", formatter: CMDx::LogFormatters::Logstash.new)
end
```

### Task-Specific Configuration

Override logging settings for individual tasks:

```ruby
class ProcessOrderTask < CMDx::Task
  task_settings!(
    logger: Rails.logger,
    log_formatter: CMDx::LogFormatters::Json.new,
    log_level: Logger::WARN
  )

  def call
    # Task implementation
  end
end

# Base class with shared logging configuration
class ApplicationTask < CMDx::Task
  task_settings!(
    logger: Logger.new("log/tasks.log"),
    log_formatter: CMDx::LogFormatters::Logstash.new,
    log_level: Logger::INFO
  )
end
```

### Environment-Specific Configuration

```ruby
CMDx.configure do |config|
  case Rails.env
  when 'development'
    config.logger = Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new)
    config.logger.level = Logger::DEBUG

  when 'test'
    config.logger = Logger.new("log/test.log", formatter: CMDx::LogFormatters::Line.new)
    config.logger.level = Logger::WARN

  when 'production'
    config.logger = Logger.new("log/production.log", formatter: CMDx::LogFormatters::Logstash.new)
    config.logger.level = Logger::INFO
  end
end
```

## Severity Mapping

CMDx automatically maps result statuses to appropriate log severity levels:

| Result Status | Log Level | Use Case |
| ------------- | --------- | -------- |
| `success`     | `INFO`    | Normal successful completion |
| `skipped`     | `WARN`    | Intentional skip (business logic) |
| `failed`      | `ERROR`   | Task failure or exception |

## Manual Logging

Access the configured logger within tasks for custom log messages:

```ruby
class ProcessOrderTask < CMDx::Task
  def call
    logger.info "Starting order processing for order #{context.order_id}"

    # Debug logging with block for performance
    logger.debug { "Order details: #{context.order.inspect}" }

    # Structured logging
    logger.info "Payment processed", {
      order_id: context.order_id,
      amount: context.order.total,
      payment_method: context.payment_method.type
    }

    # Error logging with exception details
    begin
      risky_operation
    rescue StandardError => e
      logger.error "Operation failed: #{e.message}", {
        exception: e.class.name,
        backtrace: e.backtrace.first(5)
      }
      raise
    end
  end
end
```

## Advanced Formatter Usage

### JSON Formatter for Structured Logging

```ruby
class ProcessApiTask < CMDx::Task
  task_settings!(
    logger: Logger.new("log/api.log", formatter: CMDx::LogFormatters::Json.new)
  )

  def call
    logger.info "API request initiated", {
      endpoint: context.endpoint,
      method: context.http_method,
      user_id: context.user_id
    }
  end
end

# Sample JSON output:
# {"severity":"INFO","pid":1234,"timestamp":"2022-07-17T18:43:15.000000","endpoint":"/api/orders","method":"POST","user_id":123,"origin":"CMDx"}
```

### Custom Formatter

Create custom formatters for specific output requirements:

```ruby
class SlackLogFormatter
  def call(severity, time, task, message)
    emoji = case severity
            when 'INFO' then '✅'
            when 'WARN' then '⚠️'
            when 'ERROR' then '❌'
            else '📝'
            end

    "#{emoji} #{task.class.name}: #{message}\n"
  end
end

class SendNotificationTask < CMDx::Task
  task_settings!(
    logger: Logger.new("log/notifications.log", formatter: SlackLogFormatter.new)
  )
end
```

### Multi-Destination Logging

```ruby
class MultiLogger
  def initialize(*loggers)
    @loggers = loggers
  end

  %w[debug info warn error fatal].each do |level|
    define_method(level) do |message = nil, &block|
      @loggers.each { |logger| logger.send(level, message, &block) }
    end
  end

  def formatter=(formatter)
    @loggers.each { |logger| logger.formatter = formatter }
  end

  def level=(level)
    @loggers.each { |logger| logger.level = level }
  end
end

# Usage
CMDx.configure do |config|
  config.logger = MultiLogger.new(
    Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new),
    Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Json.new)
  )
end
```

## Log Data Structure

CMDx logs contain comprehensive execution metadata:

### Standard Fields
- `severity` - Log level (INFO, WARN, ERROR)
- `pid` - Process ID for multi-process debugging
- `timestamp` - ISO 8601 formatted execution time
- `origin` - Always "CMDx" for filtering

### Task Identification
- `index` - Position in execution sequence
- `run_id` - Unique identifier for execution run
- `type` - Task or Batch
- `class` - Task class name
- `id` - Unique task instance identifier
- `tags` - Custom tags for categorization

### Execution Information
- `state` - Execution lifecycle state (initialized, executing, complete, interrupted)
- `status` - Business logic outcome (success, skipped, failed)
- `outcome` - Final result classification
- `metadata` - Custom data from skip!/fail! calls
- `runtime` - Execution time in seconds

### Failure Chain (Complex Workflows)
- `caused_failure` - Original failing task information
- `threw_failure` - Task that propagated the failure

## Best Practices

### Performance Optimization

```ruby
class ProcessOptimizedTask < CMDx::Task
  def call
    # Use block form for expensive debug logging
    logger.debug { expensive_debug_data.inspect }

    # Avoid string interpolation in log messages when possible
    logger.info "Processing item", { item_id: context.item_id }

    # Use appropriate log levels
    logger.debug "Detailed processing steps"  # Development only
    logger.info "Major milestones"            # Production relevant
    logger.warn "Recoverable issues"          # Attention needed
    logger.error "Critical failures"          # Immediate action required
  end
end
```

### Structured Logging

```ruby
class ProcessStructuredLoggingTask < CMDx::Task
  def call
    # Include contextual information
    logger.info "Task started", {
      user_id: context.user_id,
      request_id: context.request_id,
      feature_flags: context.feature_flags
    }

    # Log business events
    logger.info "Order validated", {
      order_id: context.order.id,
      validation_rules: applied_rules,
      validation_time: validation_duration
    }
  end
end
```

### Security Considerations

```ruby
class ProcessSecureLoggingTask < CMDx::Task
  def call
    # Never log sensitive information
    logger.info "Payment processed", {
      order_id: context.order_id,
      amount: context.amount,
      # ❌ DON'T: credit_card_number: context.payment.card_number
      payment_method: context.payment.card_type,
      last_four: context.payment.card_number.last(4)
    }

    # Sanitize user input in logs
    logger.debug "User input received", {
      sanitized_input: sanitize_for_logging(context.user_input)
    }
  end

  private

  def sanitize_for_logging(input)
    # Remove or mask sensitive patterns
    input.to_s.gsub(/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/, '[CARD_NUMBER]')
  end
end
```

### Monitoring Integration

```ruby
# Application Performance Monitoring integration
class ProcessMonitoredTask < CMDx::Task
  after_execution :send_metrics_to_apm

  private

  def send_metrics_to_apm
    NewRelic::Agent.record_metric(
      "Custom/CMDx/#{self.class.name}",
      result.runtime
    )

    if result.failed?
      NewRelic::Agent.notice_error(
        StandardError.new(result.metadata[:reason]),
        custom_params: result.metadata
      )
    end
  end
end
```

---

- **Prev:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
- **Next:** [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
