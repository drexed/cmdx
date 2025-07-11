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

## TLDR

- **Hierarchy** - Global → Task Settings → Runtime (each level overrides previous)
- **Global config** - Framework-wide defaults via `CMDx.configure`
- **Task settings** - Class-level overrides using `cmd_settings!`
- **Key options** - `task_halt`, `workflow_halt`, `logger`, `middlewares`, `callbacks`
- **Generator** - Use `rails g cmdx:install` to create configuration file
- **Inheritance** - Settings are inherited from parent classes

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

This creates `config/initializers/cmdx.rb` with default settings.

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

Configure middlewares that automatically apply to all tasks in your application:

```ruby
CMDx.configure do |config|
  # Add middlewares without arguments
  config.middlewares.use CMDx::Middlewares::Timeout

  # Add middlewares with arguments
  config.middlewares.use CMDx::Middlewares::Timeout, seconds: 30

  # Add middleware instances
  config.middlewares.use CMDx::Middlewares::Timeout.new(seconds: 30)
end
```

### Global Callbacks

Configure callbacks that automatically apply to all tasks in your application:

```ruby
CMDx.configure do |config|
  # Add method callbacks
  config.callbacks.register :before_execution, :log_task_start

  # Add callback instances
  config.callbacks.register :on_success, NotificationCallback.new([:slack])

  # Add conditional callbacks
  config.callbacks.register :on_failure, :page_admin, if: :production?

  # Add proc callbacks
  config.callbacks.register :on_complete, proc { |task, type|
    Metrics.increment("task.#{task.class.name.underscore}.completed")
  }
end
```

### Global Coercions

Configure custom coercions that automatically apply to all tasks in your application:

```ruby
CMDx.configure do |config|
  # Add custom coercion classes
  config.coercions.register :money, MoneyCoercion

  # Add complex coercions with options support
  config.coercions.register :tags, proc { |value, options|
    separator = options[:separator] || ','
    max_tags = options[:max_tags] || 10

    tags = value.to_s.split(separator).map(&:strip).reject(&:empty?)
    tags = tags.first(max_tags) if max_tags
    tags.uniq
  }
end
```

### Global Validators

Configure validators that automatically apply to all tasks in your application:

```ruby
CMDx.configure do |config|
  # Add validator classes
  config.validators.register :email, EmailValidator

  # Add complex validators with options support
  config.validators.register :phone, proc { |value, options|
    country = options.dig(:phone, :country) || "US"
    case country
    when "US"
      value.match?(/\A\d{3}-\d{3}-\d{4}\z/)
    else
      value.match?(/\A\+?\d{10,15}\z/)
    end
  }
end
```

## Task Settings

Override global configuration for specific tasks or workflows using `cmd_settings!`:

```ruby
class ProcessPaymentTask < CMDx::Task
  cmd_settings!(
    task_halt: ["failed"],                       # Only halt on failures
    tags: ["payments", "critical"],              # Add logging tags
    logger: Rails.logger,                        # Use Rails logger
    log_level: :info,                            # Set log level
    log_formatter: CMDx::LogFormatters::Json.new # JSON formatter
  )

  def call
    # Process payment logic
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

### Workflow Configuration

Configure halt behavior for workflows:

```ruby
class OrderProcessingWorkflow < CMDx::Workflow
  # Strict workflow - halt on any failure
  cmd_settings!(workflow_halt: ["failed", "skipped"])

  process ValidateOrderTask
  process ChargePaymentTask
  process FulfillOrderTask
end
```

## Configuration Management

### Accessing Configuration

```ruby
# Global configuration
CMDx.configuration.logger      #=> <Logger instance>
CMDx.configuration.task_halt   #=> "failed"
CMDx.configuration.middlewares #=> <MiddlewareRegistry instance>
CMDx.configuration.callbacks   #=> <CallbackRegistry instance>
CMDx.configuration.coercions   #=> <CoercionRegistry instance>
CMDx.configuration.validators  #=> <ValidatorRegistry instance>

# Task-specific settings
class AnalyzeDataTask < CMDx::Task
  cmd_settings!(tags: ["analytics"])

  def call
    tags = cmd_setting(:tags)               # Gets ["analytics"]
    halt_statuses = cmd_setting(:task_halt) # Gets global default
  end
end
```

### Resetting Configuration

Reset configuration to defaults (useful for testing):

```ruby
CMDx.reset_configuration!
CMDx.configuration.task_halt #=> "failed" (default)
```

---

- **Prev:** [Getting Started](getting_started.md)
- **Next:** [Basics - Setup](basics/setup.md)
