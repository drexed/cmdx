# Logging

CMDx provides comprehensive automatic logging for task execution with structured data, customizable formatters, and intelligent severity mapping. All task results are logged after completion with rich metadata for debugging and monitoring.

## Table of Contents
- [TLDR](#tldr)
- [Log Formatters](#log-formatters)
  - [Standard Formatters](#standard-formatters)
  - [Stylized Formatters](#stylized-formatters)
- [Sample Output](#sample-output)
- [Configuration](#configuration)
  - [Global Configuration](#global-configuration)
  - [Task-Specific Configuration](#task-specific-configuration)
- [Severity Mapping](#severity-mapping)
- [Manual Logging](#manual-logging)
- [Error Handling](#error-handling)
- [Advanced Usage](#advanced-usage)
  - [Custom Formatters](#custom-formatters)
  - [Multi-Destination Logging](#multi-destination-logging)
- [Log Data Structure](#log-data-structure)

## TLDR

```ruby
# Automatic logging - no setup required
class ProcessOrder < CMDx::Task
  def work
    # Task execution automatically logged with metadata
  end
end

# Custom formatter
settings(log_formatter: CMDx::LogFormatters::Json.new)

# Manual logging within tasks
logger.info "Processing order", order_id: context.order_id

# Global configuration
CMDx.configure do |config|
  config.logger = Logger.new("log/cmdx.log")
  config.log_formatter = CMDx::LogFormatters::Json.new
end
```

## Log Formatters

> [!NOTE]
> All formatters automatically include execution metadata. Choose based on your environment: stylized for development, standard for production.

### Standard Formatters

| Formatter | Use Case | Output Style |
|-----------|----------|--------------|
| `Line` | Traditional logging | Single-line format |
| `Json` | Structured systems | Compact JSON |
| `KeyValue` | Log parsing | `key=value` pairs |
| `Logstash` | ELK stack | JSON with @version/@timestamp |
| `Raw` | Minimal output | Message content only |

### Stylized Formatters

> [!TIP]
> Stylized formatters include ANSI color codes for better terminal readability in development environments.

| Formatter | Description |
|-----------|-------------|
| `PrettyLine` | Colorized line format (default) |
| `PrettyJson` | Multi-line JSON with syntax highlighting |
| `PrettyKeyValue` | Colorized key=value pairs |

## Sample Output

```ruby
# Success (INFO level)
I, [2022-07-17T18:43:15.000000 #3784] INFO -- CreateOrderTask:
index=0 chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task
class=CreateOrderTask status=success metadata={order_id: 123} runtime=0.45

# Skipped (WARN level)
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidatePaymentTask:
index=1 status=skipped metadata={Order already processed"} runtime=0.02

# Failed (ERROR level)
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessPaymentTask:
index=2 status=failed metadata={error_code: "INSUFFICIENT_FUNDS"} runtime=0.15

# Workflow failure chain
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- OrderWorkflow:
caused_failure={index: 2, class: "ProcessPaymentTask", status: "failed"}
threw_failure={index: 1, class: "ValidatePaymentTask", status: "failed"}
```

## Configuration

### Global Configuration

```ruby
CMDx.configure do |config|
  config.logger = Logger.new("log/cmdx.log")
  config.log_formatter = CMDx::LogFormatters::Json.new
  config.log_level = Logger::INFO
end
```

### Task-Specific Configuration

```ruby
class SendEmail < CMDx::Task
  settings(
    logger: Rails.logger,
    log_formatter: CMDx::LogFormatters::Logstash.new,
    log_level: Logger::WARN
  )

  def work
    # Task implementation
  end
end

# Base class configuration
class Application < CMDx::Task
  settings(
    logger: Logger.new("log/tasks.log"),
    log_formatter: CMDx::LogFormatters::Json.new
  )
end
```

## Severity Mapping

> [!IMPORTANT]
> CMDx automatically maps result statuses to log severity levels. Manual overrides are not recommended as they break monitoring conventions.

| Status | Log Level | When Used |
|--------|-----------|-----------|
| `success` | `INFO` | Normal completion |
| `skipped` | `WARN` | Intentional skip via business logic |
| `failed` | `ERROR` | Task failure or exception |

## Manual Logging

```ruby
class ProcessOrder < CMDx::Task
  def work
    # Structured logging with metadata
    logger.info "Starting order processing", order_id: context.order_id

    # Performance-optimized debug logging
    logger.debug { "Order details: #{context.order.inspect}" }

    # Exception context
    begin
      validate_inventory
    rescue StandardError => e
      logger.error "Inventory validation failed", {
        exception: e.class.name,
        order_id: context.order_id,
        message: e.message
      }
      raise
    end

    # Success with metadata
    logger.info "Order processed successfully", {
      order_id: context.order_id,
      amount: context.order.total
    }
  end
end
```

## Error Handling

> [!WARNING]
> Logger configuration errors are handled gracefully, falling back to STDOUT with PrettyLine formatter to ensure execution continuity.

### Configuration Error Recovery

```ruby
# Invalid logger configuration
CMDx.configure do |config|
  config.logger = Logger.new("/invalid/path/cmdx.log")  # Permission denied
end

# CMDx automatically falls back to:
# Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new)
```

### Formatter Error Handling

```ruby
class BrokenFormatter
  def work(severity, time, task, message)
    raise StandardError, "Formatter error"
  end
end

class Test < CMDx::Task
  settings(log_formatter: BrokenFormatter.new)

  def work
    # Execution continues with fallback formatter
    # Error logged to STDERR for debugging
  end
end
```

### Log Level Validation

```ruby
# Invalid log levels default to INFO
CMDx.configure do |config|
  config.log_level = "INVALID"  #=> Logger::INFO
end

# Valid levels: DEBUG, INFO, WARN, ERROR, FATAL
```

## Advanced Usage

### Custom Formatters

```ruby
class AlertFormatter
  def work(severity, time, task, message)
    emoji = case severity
            when 'INFO' then '✅'
            when 'WARN' then '⚠️'
            when 'ERROR' then '❌'
            else '📝'
            end

    "[#{time.strftime('%H:%M:%S')}] #{emoji} #{task.class.name}: #{message}\n"
  end
end

class Notification < CMDx::Task
  settings(log_formatter: AlertFormatter.new)

  def work
    # Uses custom emoji-based formatting
  end
end
```

### Multi-Destination Logging

> [!TIP]
> Combine multiple loggers to output to both console and files simultaneously during development.

```ruby
class MultiLogger
  def initialize(*loggers)
    @loggers = loggers
  end

  %w[debug info warn error fatal].each do |level|
    define_method(level) do |message = nil, **metadata, &block|
      @loggers.each { |logger| logger.send(level, message, **metadata, &block) }
    end
  end
end

# Configuration
CMDx.configure do |config|
  config.logger = MultiLogger.new(
    Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new),
    Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Json.new)
  )
end
```

## Log Data Structure

> [!NOTE]
> All log entries include comprehensive execution metadata for debugging and monitoring. Field availability depends on the execution context.

### Core Fields

| Field | Description | Example |
|-------|-------------|---------|
| `severity` | Log level | `INFO`, `WARN`, `ERROR` |
| `timestamp` | ISO 8601 execution time | `2022-07-17T18:43:15.000000` |
| `pid` | Process ID | `3784` |
| `origin` | Source identifier | `CMDx` |

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
| `runtime` | Execution time (seconds) | `0.45` |

### Failure Chain (Workflows)

| Field | Description |
|-------|-------------|
| `caused_failure` | Original failing task details |
| `threw_failure` | Task that propagated the failure |

---

- **Prev:** [Workflows](workflows.md)
- **Next:** [Internationalization (i18n)](internationalization.md)
