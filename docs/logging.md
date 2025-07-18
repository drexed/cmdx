# Logging

CMDx provides comprehensive automatic logging for task execution with structured data, customizable formatters, and intelligent severity mapping. All task results are logged after completion with rich metadata for debugging and monitoring.

## Table of Contents
- [TLDR](#tldr)
- [Log Formatters](#log-formatters)
  - [Standard Formatters](#standard-formatters)
  - [Stylized Formatters (ANSI Colors)](#stylized-formatters-ansi-colors)
- [Sample Output](#sample-output)
  - [Success Result](#success-result)
  - [Skipped Result](#skipped-result)
  - [Failed Result](#failed-result)
  - [Failure Chain (Workflow Workflows)](#failure-chain-workflow-workflows)
- [Configuration](#configuration)
  - [Global Configuration](#global-configuration)
  - [Task-Specific Configuration](#task-specific-configuration)
  - [Environment-Specific Configuration](#environment-specific-configuration)
- [Severity Mapping](#severity-mapping)
- [Manual Logging](#manual-logging)
- [Advanced Formatter Usage](#advanced-formatter-usage)
  - [Custom Formatter](#custom-formatter)
  - [Multi-Destination Logging](#multi-destination-logging)
- [Log Data Structure](#log-data-structure)

## TLDR

- **Automatic logging** - All task results logged after completion with structured data
- **8 formatters** - Standard (Line, Json, KeyValue, Logstash, Raw) and Stylized (Pretty variants)
- **Configuration** - Global via `CMDx.configure` or task-specific via `cmd_settings!`
- **Severity mapping** - Success=INFO, Skipped=WARN, Failed=ERROR
- **Rich metadata** - Includes runtime, chain_id, status, context, and failure chains
- **Manual logging** - Access `logger` within tasks for custom messages

## Log Formatters

CMDx provides 8 built-in log formatters organized into standard and stylized categories:

### Standard Formatters
- **`Line`** - Traditional single-line format similar to Ruby's Logger
- **`Json`** - Compact single-line JSON for structured logging systems
- **`KeyValue`** - Space-separated key=value pairs for easy parsing
- **`Logstash`** - ELK stack compatible JSON with @version and @timestamp fields
- **`Raw`** - Minimal output containing only the message content

### Stylized Formatters (ANSI Colors)

> [!NOTE]
> Stylized formatters include ANSI color codes for terminal readability and are best suited for development environments.

- **`PrettyLine`** - Colorized line format (default)
- **`PrettyJson`** - Human-readable multi-line JSON with syntax highlighting
- **`PrettyKeyValue`** - Colorized key=value pairs for terminal readability

## Sample Output

### Success Result
```txt
I, [2022-07-17T18:43:15.000000 #3784] INFO -- CreateOrderTask: index=0 chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=CreateOrderTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=complete status=success outcome=success metadata={order_id: 123, confirmation: "ABC123"} runtime=0.45 origin=CMDx
```

### Skipped Result
```txt
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidatePaymentTask: index=0 chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=ValidatePaymentTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=skipped outcome=skipped metadata={reason: "Order already processed"} runtime=0.02 origin=CMDx
```

### Failed Result
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessPaymentTask: index=0 chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Task class=ProcessPaymentTask id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=failed outcome=failed metadata={reason: "Payment declined", error_code: "INSUFFICIENT_FUNDS"} runtime=0.15 origin=CMDx
```

### Failure Chain (Workflow Workflows)
```txt
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- OrderCreationWorkflow: index=0 chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5 type=Workflow class=OrderCreationWorkflow id=018c2b95-b764-7615-a924-cc5b910ed1e5 tags=[] state=interrupted status=failed outcome=interrupted metadata={} runtime=0.75 caused_failure={index: 2, class: "ValidatePaymentTask", status: "failed"} threw_failure={index: 1, class: "ProcessPaymentTask", status: "failed"} origin=CMDx
```

## Configuration

### Global Configuration

Configure logging globally in your CMDx initializer:

```ruby
CMDx.configure do |config|
  config.logger = Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Json.new)
  config.logger.level = Logger::INFO
end
```

### Task-Specific Configuration

Override logging settings for individual tasks:

```ruby
class SendEmailTask < CMDx::Task
  cmd_settings!(
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
  cmd_settings!(
    logger: Logger.new("log/tasks.log"),
    log_formatter: CMDx::LogFormatters::Logstash.new,
    log_level: Logger::INFO
  )
end
```

## Severity Mapping

> [!IMPORTANT]
> CMDx automatically maps result statuses to appropriate log severity levels. Manual log level overrides are not recommended.

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
    logger.info "Starting order processing", order_id: context.order_id

    # Performance-optimized debug logging
    logger.debug { "Order details: #{context.order.inspect}" }

    # Structured logging
    logger.info "Payment processed", {
      order_id: context.order_id,
      amount: context.order.total,
      payment_method: context.payment_method
    }

    # Exception handling with logging
    begin
      validate_inventory
    rescue StandardError => e
      logger.error "Inventory validation failed: #{e.message}", {
        exception: e.class.name,
        order_id: context.order_id
      }
      raise
    end
  end
end
```

## Advanced Formatter Usage

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
  cmd_settings!(
    logger: Logger.new("log/notifications.log", formatter: SlackLogFormatter.new)
  )
end
```

### Multi-Destination Logging

> [!TIP]
> Use multi-destination logging to send output to both console and files simultaneously during development.

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

#### Standard Fields
- `severity` - Log level (INFO, WARN, ERROR)
- `pid` - Process ID for multi-process debugging
- `timestamp` - ISO 8601 formatted execution time
- `origin` - Always "CMDx" for filtering

#### Task Identification
- `index` - Position in execution sequence
- `chain_id` - Unique identifier for execution chain
- `type` - Task or Workflow
- `class` - Task class name
- `id` - Unique task instance identifier
- `tags` - Custom tags for categorization

#### Execution Information
- `state` - Execution lifecycle state (initialized, executing, complete, interrupted)
- `status` - Business logic outcome (success, skipped, failed)
- `outcome` - Final result classification
- `metadata` - Custom data from skip!/fail! calls
- `runtime` - Execution time in seconds

#### Failure Chain (Complex Workflows)
- `caused_failure` - Original failing task information
- `threw_failure` - Task that propagated the failure

---

- **Prev:** [Workflows](workflows.md)
- **Next:** [Internationalization (i18n)](internationalization.md)
