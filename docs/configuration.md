# Configuration

CMDx provides a flexible configuration system that allows customization at both global and task levels. Configuration follows a hierarchy where global settings serve as defaults that can be overridden at the task level.

## Table of Contents

- [TLDR](#tldr)
- [Configuration Hierarchy](#configuration-hierarchy)
- [Global Configuration](#global-configuration)
  - [Configuration Options](#configuration-options)
  - [Global Middlewares](#global-middlewares)
  - [Global Callbacks](#global-callbacks)
  - [Global Coercions](#global-coercions)
  - [Global Validators](#global-validators)
- [Task Settings](#task-settings)
  - [Available Task Settings](#available-task-settings)
  - [Workflow Configuration](#workflow-configuration)
- [Configuration Management](#configuration-management)
  - [Accessing Configuration](#accessing-configuration)
  - [Resetting Configuration](#resetting-configuration)
- [Error Handling](#error-handling)

## TLDR

```ruby
# Generate configuration file
rails g cmdx:install

# Global configuration
CMDx.configure do |config|
  config.task_halt = ["failed", "skipped"]     # Multiple halt statuses
  config.logger = Rails.logger                 # Custom logger
  config.middlewares.use TimeoutMiddleware     # Global middleware
  config.callbacks.register :on_failure, :log # Global callback
end

# Task-level overrides
class PaymentTask < CMDx::Task
  cmd_settings!(task_halt: "failed", tags: ["payments"])

  def call
    halt_on = cmd_setting(:task_halt)  # Access settings
  end
end
```

## Configuration Hierarchy

CMDx follows a three-tier configuration hierarchy:

1. **Global Configuration**: Framework-wide defaults
2. **Task Settings**: Class-level overrides via `cmd_settings!`
3. **Runtime Parameters**: Instance-specific overrides during execution

> [!IMPORTANT]
> Task-level settings take precedence over global configuration. Settings are inherited from superclasses and can be overridden in subclasses.

## Global Configuration

Generate a configuration file using the Rails generator:

```bash
rails g cmdx:install
```

This creates `config/initializers/cmdx.rb` with sensible defaults.

### Configuration Options

| Option        | Type                  | Default        | Description |
|---------------|-----------------------|----------------|-------------|
| `task_halt`   | String, Array<String> | `"failed"`     | Result statuses that cause `call!` to raise faults |
| `workflow_halt`  | String, Array<String> | `"failed"`     | Result statuses that halt workflow execution |
| `logger`      | Logger                | Line formatter | Logger instance for task execution logging |
| `middlewares` | MiddlewareRegistry    | Empty registry | Global middleware registry applied to all tasks |
| `callbacks`   | CallbackRegistry      | Empty registry | Global callback registry applied to all tasks |
| `coercions`   | CoercionRegistry      | Built-in coercions | Global coercion registry for custom parameter types |
| `validators`  | ValidatorRegistry     | Built-in validators | Global validator registry for parameter validation |

### Global Middlewares

Configure middlewares that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  # Simple middleware registration
  config.middlewares.use CMDx::Middlewares::Timeout

  # Middleware with configuration
  config.middlewares.use CMDx::Middlewares::Timeout, seconds: 30

  # Multiple middlewares
  config.middlewares.use AuthenticationMiddleware
  config.middlewares.use LoggingMiddleware, level: :debug
  config.middlewares.use MetricsMiddleware, namespace: "app.tasks"
end
```

> [!NOTE]
> Middlewares are executed in registration order. Each middleware wraps the next, creating an execution chain around task logic.

### Global Callbacks

Configure callbacks that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  # Method callbacks
  config.callbacks.register :before_execution, :setup_request_context
  config.callbacks.register :after_execution, :cleanup_temp_files

  # Conditional callbacks
  config.callbacks.register :on_failure, :notify_admin, if: :production?
  config.callbacks.register :on_success, :update_metrics, unless: :test?

  # Proc callbacks with context
  config.callbacks.register :on_complete, proc { |task, type|
    duration = task.metadata[:runtime]
    StatsD.histogram("task.duration", duration, tags: ["class:#{task.class.name}"])
  }
end
```

### Global Coercions

Configure custom coercions for domain-specific types:

```ruby
CMDx.configure do |config|
  # Simple coercion classes
  config.coercions.register :money, MoneyCoercion
  config.coercions.register :email, EmailCoercion

  # Complex coercions with options
  config.coercions.register :csv_array, proc { |value, options|
    separator = options[:separator] || ','
    max_items = options[:max_items] || 100

    items = value.to_s.split(separator).map(&:strip).reject(&:empty?)
    items.first(max_items)
  }
end
```

### Global Validators

Configure custom validators for parameter validation:

```ruby
CMDx.configure do |config|
  # Validator classes
  config.validators.register :email, EmailValidator
  config.validators.register :phone, PhoneValidator

  # Proc validators with options
  config.validators.register :api_key, proc { |value, options|
    required_prefix = options.dig(:api_key, :prefix) || "sk_"
    min_length = options.dig(:api_key, :min_length) || 32

    value.start_with?(required_prefix) && value.length >= min_length
  }
end
```

## Task Settings

Override global configuration for specific tasks using `cmd_settings!`:

```ruby
class ProcessPaymentTask < CMDx::Task
  cmd_settings!(
    task_halt: ["failed"],                          # Only halt on failures
    tags: ["payments", "critical"],                 # Logging tags
    logger: PaymentLogger.new,                      # Custom logger
    log_level: :info,                               # Log level override
    log_formatter: CMDx::LogFormatters::Json.new    # JSON formatting
  )

  def call
    # Payment processing logic
    charge_customer(amount, payment_method)
  end

  private

  def charge_customer(amount, method)
    # Implementation details
  end
end
```

### Available Task Settings

| Setting         | Type                  | Description |
|-----------------|-----------------------|-------------|
| `task_halt`     | String, Array<String> | Result statuses that cause `call!` to raise faults |
| `workflow_halt`    | String, Array<String> | Result statuses that halt workflow execution |
| `tags`          | Array<String>         | Tags automatically appended to logs |
| `logger`        | Logger                | Custom logger instance |
| `log_level`     | Symbol                | Log level (`:debug`, `:info`, `:warn`, `:error`, `:fatal`) |
| `log_formatter` | LogFormatter          | Custom log formatter |

> [!TIP]
> Use task-level settings for tasks that require special handling, such as payment processing, external API calls, or critical system operations.

### Workflow Configuration

Configure halt behavior and logging for workflows:

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  # Halt on any non-success status
  cmd_settings!(
    workflow_halt: ["failed", "skipped"],
    tags: ["orders", "e-commerce"],
    log_level: :info
  )

  process ValidateOrderTask
  process ChargePaymentTask
  process UpdateInventoryTask
  process SendConfirmationTask
end

class DataMigrationWorkflow < CMDx::Workflow
  # Continue on skipped tasks, halt only on failures
  cmd_settings!(
    workflow_halt: "failed",
    tags: ["migration", "maintenance"]
  )

  process BackupDataTask
  process MigrateUsersTask
  process MigrateOrdersTask
  process ValidateDataTask
end
```

## Configuration Management

### Accessing Configuration

```ruby
# Global configuration access
CMDx.configuration.logger                    #=> <Logger instance>
CMDx.configuration.task_halt                 #=> "failed"
CMDx.configuration.middlewares.middlewares   #=> [<Middleware>, ...]
CMDx.configuration.callbacks.callbacks       #=> {before_execution: [...], ...}

# Task-specific settings
class DataProcessingTask < CMDx::Task
  cmd_settings!(
    tags: ["data", "analytics"],
    task_halt: ["failed", "skipped"]
  )

  def call
    # Access current task settings
    log_tags = cmd_setting(:tags)               #=> ["data", "analytics"]
    halt_on = cmd_setting(:task_halt)           #=> ["failed", "skipped"]
    logger_instance = cmd_setting(:logger)      #=> Inherited from global
  end
end
```

### Resetting Configuration

> [!WARNING]
> Resetting configuration affects the entire application. Use primarily in test environments or during application initialization.

```ruby
# Reset to framework defaults
CMDx.reset_configuration!

# Verify reset
CMDx.configuration.task_halt     #=> "failed" (default)
CMDx.configuration.middlewares   #=> Empty registry
CMDx.configuration.callbacks     #=> Empty registry

# Commonly used in test setup
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

## Error Handling

### Configuration Validation

```ruby
# Invalid configuration types
CMDx.configure do |config|
  config.task_halt = :invalid_type    # Error: must be String or Array
  config.logger = "not_a_logger"      # Error: must respond to logging methods
end
```

### Missing Settings Access

```ruby
class ExampleTask < CMDx::Task
  def call
    # Accessing non-existent setting
    value = cmd_setting(:non_existent_setting)  #=> nil (returns nil for undefined)

    # Check if setting exists
    if cmd_setting(:custom_timeout)
      timeout = cmd_setting(:custom_timeout)
    else
      timeout = 30  # fallback
    end
  end
end
```

### Configuration Conflicts

```ruby
# Parent class configuration
class BaseTask < CMDx::Task
  cmd_settings!(task_halt: "failed", tags: ["base"])
end

# Child class inherits and overrides
class SpecialTask < BaseTask
  cmd_settings!(task_halt: ["failed", "skipped"])  # Overrides parent
  # tags: ["base"] inherited from parent

  def call
    halt_statuses = cmd_setting(:task_halt)  #=> ["failed", "skipped"]
    inherited_tags = cmd_setting(:tags)      #=> ["base"]
  end
end
```

> [!IMPORTANT]
> Settings inheritance follows Ruby's method resolution order. Child class settings always override parent class settings for the same key.

---

- **Prev:** [Getting Started](getting_started.md)
- **Next:** [Basics - Setup](basics/setup.md)
