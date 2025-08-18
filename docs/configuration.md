# Configuration

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic parameter validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Table of Contents

- [Installation](#installation)
- [Configuration Hierarchy](#configuration-hierarchy)
- [Global Configuration](#global-configuration)
  - [Breakpoints](#breakpoints)
  - [Logging](#logging)
  - [Middlewares](#middlewares)
  - [Callbacks](#callbacks)
  - [Coercions](#coercions)
  - [Validators](#validators)
- [Task Configuration](#task-configuration)
  - [Settings](#settings)
  - [Register](#register)
- [Configuration Management](#configuration-management)
  - [Access](#access)
  - [Resetting](#resetting)
- [Task Generator](#task-generator)

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

This creates `config/initializers/cmdx.rb` file.

## Configuration Hierarchy

CMDx follows a two-tier configuration hierarchy:

1. **Global Configuration**: Framework-wide defaults
2. **Task Settings**: Class-level overrides via `settings`

> [!IMPORTANT]
> Task-level settings take precedence over global configuration.
> Settings are inherited from superclasses and can be overridden in subclasses.

## Global Configuration

The CMDx global configuration is initialized with sensible defaults.

### Breakpoints

Breakpoints control when `execute!` raises faults.

Configure breakpoints that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  config.task_breakpoints = "skipped"
  config.workflow_breakpoints = ["skipped", "failed"]
end
```

### Logging

Configure logger that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  config.logger = CustomLogger.new($stdout)
end
```

### Middlewares

Configure middlewares that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  # Via object
  config.middlewares.register CMDx::Middlewares::Timeout

  # Via proc
  config.middlewares.register proc { |task, options|
    start = Time.now
    result = yield
    finish = Time.now
    Rails.logger.debug { "task complete in #{finish - start}ms" }
    result
  }

  # With options
  config.middlewares.register MetricsMiddleware, namespace: "app.tasks"

  # Remove middleware
  config.middlewares.deregister CMDx::Middlewares::Timeout
end
```

> [!NOTE]
> Middlewares are executed in registration order. Each middleware wraps the next,
> creating an execution chain around task logic.

### Callbacks

Configure callbacks that automatically apply to all tasks:

```ruby
CMDx.configure do |config|
  # Via method
  config.callbacks.register :before_execution, :setup_request_context

  # Via object
  config.callbacks.register :on_success, TrackSuccessfulPurchase

  # Via proc
  config.callbacks.register :on_complete, proc { |task|
    duration = task.metadata[:runtime]
    StatsD.histogram("task.duration", duration, tags: ["class:#{task.class.name}"])
  }

  # With options
  config.callbacks.register :on_failure, :notify_admin, if: :production?

  # Remove callback
  config.callbacks.deregister :on_success, TrackSuccessfulPurchase
end
```

### Coercions

Configure custom coercions for domain-specific types:

```ruby
CMDx.configure do |config|
  # Via object
  config.coercions.register :money, MoneyCoercion

  # Via method
  config.coercions.register :point, :point_coercion

  # Via proc
  config.coercions.register :csv_array, proc { |value, options|
    separator = options[:separator] || ','
    max_items = options[:max_items] || 100

    items = value.to_s.split(separator).map(&:strip).reject(&:empty?)
    items.first(max_items)
  }

  # Remove coercion
  config.coercions.deregister :money
end
```

### Validators

Configure custom validators for parameter validation:

```ruby
CMDx.configure do |config|
  # Via object
  config.validators.register :email, EmailValidator

  # Via method
  config.validators.register :phone, :phone_validator

  # Via proc
  config.validators.register :api_key, proc { |value, options|
    required_prefix = options[:prefix] || "sk_"
    min_length = options[:min_length] || 32

    value.start_with?(required_prefix) && value.length >= min_length
  }

  # Remove validator
  config.validators.deregister :email
end
```

## Task Configuration

### Settings

Override global configuration for specific tasks using `settings`:

```ruby
class ProcessPayment < CMDx::Task
  settings(
    # Global configuration overrides
    task_breakpoints: ["failed"],                   # Breakpoint override
    workflow_breakpoints: [],                       # Breakpoint override
    logger: CustomLogger.new($stdout),              # Custom logger

    # Task configuration settings
    log_level: :info,                               # Log level override
    log_formatter: CMDx::LogFormatters::Json.new    # Log formatter override
    tags: ["payments", "critical"]                  # Logging tags
  )

  def work
    # Logic
  end
end
```

> [!TIP]
> Use task-level settings for tasks that require special handling, such as payment processing,
> external API calls, or critical system operations.

### Register

Register middlewares, callbacks, coercions, and validators on a specific task.
Deregister options that should not be available.

```ruby
class ProcessPayment < CMDx::Task
  # Middlewares
  register :middleware, CMDx::Middlewares::Timeout
  deregister :middleware, MetricsMiddleware

  # Callbacks
  register :callback, :on_complete, proc { |task|
    duration = task.metadata[:runtime]
    StatsD.histogram("task.duration", duration, tags: ["class:#{task.class.name}"])
  }
  deregister :callback, :before_execution, :setup_request_context

  # Coercions
  register :coercion, :money, MoneyCoercion
  deregister :coercion, :point

  # Validators
  register :validator, :email, :email_validator
  deregister :validator, :phone

  def work
    # Logic
  end
end
```

## Configuration Management

### Access

```ruby
# Global configuration access
CMDx.configuration.logger               #=> <Logger instance>
CMDx.configuration.task_breakpoints     #=> ["failed"]
CMDx.configuration.middlewares.registry #=> [<Middleware>, ...]

# Task configuration access
class DataProcessingTask < CMDx::Task
  settings(tags: ["data", "analytics"])

  def work
    self.class.settings[:logger] #=> Global configuration value
    self.class.settings[:tags]   #=> Task configuration value => ["data", "analytics"]
  end
end
```

### Resetting

> [!WARNING]
> Resetting configuration affects the entire application. Use primarily in
> test environments or during application initialization.

```ruby
# Reset to framework defaults
CMDx.reset_configuration!

# Verify reset
CMDx.configuration.task_breakpoints     #=> ["failed"] (default)
CMDx.configuration.middlewares.registry #=> Empty registry

# Commonly used in test setup (RSpec example)
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
rails generate cmdx:task TaskName
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/process_order.rb
class ProcessOrder < CMDx::Task
  def work
    # TODO: add logic here
  end
end
```

> [!TIP]
> Use **present tense verbs + noun** for task names, eg:
> `ProcessOrder`, `SendWelcomeEmail`, `ValidatePaymentDetails`

---

- **Prev:** [Tips and Tricks](tips_and_tricks.md)
- **Next:** [Basics - Setup](basics/setup.md)
