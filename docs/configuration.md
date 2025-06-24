# Configuration

CMDx provides a flexible configuration system that allows customization at both global and task levels. Configuration follows a hierarchy where global settings serve as defaults that can be overridden at the task level as needed.

## Configuration Hierarchy

CMDx follows a three-tier configuration hierarchy:

1. **Global Configuration**: Framework-wide defaults
2. **Task Settings**: Class-level overrides via `task_settings!`
3. **Runtime Parameters**: Instance-specific overrides during execution

## Global Configuration

Run `rails g cmdx:install` to generate a configuration file at `config/initializers/cmdx.rb`. These settings will be preloaded as defaults for all tasks and batches.

```ruby
CMDx.configure do |config|
  # Halt execution and raise fault on these result statuses when using `call!`
  config.task_halt = CMDx::Result::FAILED

  # Stop batch execution when tasks return these statuses
  # Note: Skipped tasks continue processing by default
  config.batch_halt = CMDx::Result::FAILED

  # Logger with formatter - see available formatters at:
  # https://github.com/drexed/cmdx/tree/main/lib/cmdx/log_formatters
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
end
```

### Configuration Options

| Option           | Type                    | Default                      | Description |
| ---------------- | ----------------------- | ---------------------------- | ----------- |
| `task_halt`      | Symbol, Array<Symbol>   | `CMDx::Result::FAILED`       | Result statuses that cause `call!` to raise faults |
| `batch_halt`     | Symbol, Array<Symbol>   | `CMDx::Result::FAILED`       | Result statuses that halt batch execution |
| `logger`         | Logger                  | `Logger.new($stdout, ...)`   | Logger instance for task execution logging |

### Environment-Specific Configuration

Configure CMDx differently based on your environment:

```ruby
CMDx.configure do |config|
  # Use Rails logger in Rails applications
  config.logger = Rails.logger if defined?(Rails)

  case Rails.env
  when 'development'
    # Pretty formatting for development
    config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyLine.new)   # No timeouts in development
    config.task_halt = [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  when 'test'
    # Silent logging for faster tests
    config.logger = Logger.new('/dev/null')
  when 'production'
    # JSON logging for production systems
    config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Json.new)
    config.task_halt = CMDx::Result::FAILED  # Only halt on actual failures
  end
end
```

### Available Result Statuses

The following result statuses can be used in halt configuration:

- `CMDx::Result::SUCCESS` - Task completed successfully
- `CMDx::Result::SKIPPED` - Task was skipped intentionally
- `CMDx::Result::FAILED` - Task failed due to error or validation

### Log Formatters

CMDx includes several built-in log formatters:

```ruby
CMDx.configure do |config|
  # Available formatters:
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)           # Simple one-line format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyLine.new)     # Colorized one-line format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Json.new)           # Compact JSON format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyJson.new)     # Pretty-printed JSON format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::KeyValue.new)       # Key-value pair format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyKeyValue.new) # Colorized key-value format
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Logstash.new)       # Logstash-compatible JSON
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Raw.new)            # Raw output format
end
```

## Task Settings

Fine-tune individual tasks or batches using class-level settings with `task_settings!`. These settings override global configuration for the specific task.

```ruby
class ProcessOrderTask < CMDx::Task
  # Override global settings at the task level
  task_settings!(
    task_halt: [CMDx::Result::FAILED],   # Only halt on failures
    tags: ["orders", "payment"],         # Add tags for logging/debugging
    logger: Rails.logger,                # Use specific logger
    log_level: :debug,                   # Set log level
    log_formatter: CMDx::LogFormatters::Json.new  # Use JSON formatter
  )

  required :order_id, type: :integer
  optional :notify_user, type: :boolean, default: true

  def call
    # Do work...
  end
end
```

### Available Task Settings

| Setting         | Type                    | Description |
| --------------- | ----------------------- | ----------- |
| `task_halt`     | Symbol, Array<Symbol>   | Result statuses that cause `call!` to raise faults |
| `batch_halt`    | Symbol, Array<Symbol>   | Result statuses that halt batch execution |
| `tags`          | Array<String>           | Tags automatically appended to logs for identification |
| `logger`        | Logger                  | Custom logger instance for this task |
| `log_level`     | Symbol                  | Log level (`:debug`, `:info`, `:warn`, `:error`, `:fatal`) |
| `log_formatter` | LogFormatter            | Custom log formatter for this task |

### Batch-Specific Settings

When using batches, you can configure halt behavior:

```ruby
class BatchProcessOrders < CMDx::Batch
  # Strict batch - halt on any failure or skip
  task_settings!(batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])

  process ValidateOrderTask
  process ChargePaymentTask
  process FulfillOrderTask
end

class BatchProcessFlexible < CMDx::Batch
  # Permissive batch - never halt, always continue
  task_settings!(batch_halt: [])

  process OptionalTask1
  process OptionalTask2
  process OptionalTask3
end
```

### Logging Configuration

Customize logging behavior per task:

```ruby
class ProcessDebugTask < CMDx::Task
  # Detailed logging configuration
  task_settings!(
    logger: Logger.new('log/debug.log'),
    log_level: :debug,
    log_formatter: CMDx::LogFormatters::PrettyJson.new,
    tags: ["debug", "investigation"]
  )

  def call
    # Debug work with detailed logging...
  end
end

class ProcessProductionTask < CMDx::Task
  # Production logging configuration
  task_settings!(
    logger: Rails.logger,
    log_level: :info,
    log_formatter: CMDx::LogFormatters::Logstash.new,
    tags: ["production", "critical"]
  )

  def call
    # Production work with structured logging...
  end
end
```

## Configuration Management

### Accessing Current Configuration

```ruby
# Check current global configuration
CMDx.configuration.logger           #=> <Logger instance>
CMDx.configuration.task_halt        #=> "failed"

# Check task-specific settings
class ProcessMyTask < CMDx::Task
  task_settings!(tags: ["test"])

  def call
    # Access settings within task
    tags = task_setting(:tags)             # Gets ["test"] from task settings
    halt_statuses = task_setting(:task_halt) # Gets global default
  end
end
```

### Resetting Configuration

Reset configuration to defaults (useful for testing):

```ruby
# Reset to default configuration
CMDx.reset_configuration!

# Verify reset
CMDx.configuration.task_halt     #=> "failed" (default)
```

### Dynamic Configuration

Configure settings dynamically based on environment variables or runtime conditions:

```ruby
CMDx.configure do |config|
  # Conditional halt behavior
  config.task_halt = if ENV['STRICT_MODE'] == 'true'
    [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  else
    CMDx::Result::FAILED
  end

  # Dynamic logger configuration
  config.logger = if ENV['LOG_TO_FILE'] == 'true'
    Logger.new('log/cmdx.log', formatter: CMDx::LogFormatters::Json.new)
  else
    Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
  end
end
```

> [!NOTE]
> Task-level settings (`task_settings!`) take precedence over global configuration. The `tags` setting is task-level only and will automatically be appended to logs for easier identification and filtering.

---

- **Prev:** [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md)
- **Next:** [Basics - Setup](https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md)
